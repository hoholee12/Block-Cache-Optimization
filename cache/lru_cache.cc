//  Copyright (c) 2011-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under both the GPLv2 (found in the
//  COPYING file in the root directory) and Apache 2.0 License
//  (found in the LICENSE.Apache file in the root directory).
//
// Copyright (c) 2011 The LevelDB Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file. See the AUTHORS file for names of contributors.

#include "cache/lru_cache.h"

#include <cassert>
#include <cstdint>
#include <cstdio>

#include "monitoring/perf_context_imp.h"
#include "monitoring/statistics.h"
#include "util/mutexlock.h"



namespace ROCKSDB_NAMESPACE {

/*
Holdvalue class


*/
class Holdvalue{
private:
  uint32_t myshard;
public:
  //non copyable
  Holdvalue(const Holdvalue&) = delete;
  Holdvalue& operator=(const Holdvalue&) = delete;

  Holdvalue(uint32_t hisshard){
    myshard = hisshard;
    lockheld[myshard] = true;
  }
  ~Holdvalue(){
    lockheld[myshard] = false;
  }
};

int getmytid(){
  std::map<pthread_t, int>::iterator tidit = tids.find(pthread_self());
  int mytid = 0;
  if(tidit != tids.end()){
    mytid = tidit->second;
  }
  return mytid;
}
  
uint32_t Shard(uint32_t hash) {
  uint32_t shard_mask_ = (uint32_t{1} << numshardbits) - 1;
  return hash & shard_mask_;
}

uint32_t GetNumShards() {
  uint32_t shard_mask_ = (uint32_t{1} << numshardbits) - 1;
   return shard_mask_ + 1; 
}


LRUHandleTable::LRUHandleTable(int max_upper_hash_bits)
    : length_bits_(/* historical starting size*/ 4),
      list_(new LRUHandle* [size_t{1} << length_bits_] {}),
      elems_(0),
      max_length_bits_(max_upper_hash_bits) {}

LRUHandleTable::~LRUHandleTable() {
  
}

LRUHandle* LRUHandleTable::Lookup(const Slice& key, uint32_t hash) {
  return *FindPointer(key, hash);
}

//this replaces to new entry from old entry via same key, and returns old one?
LRUHandle* LRUHandleTable::Insert(LRUHandle* h) {
  LRUHandle** ptr = FindPointer(h->key(), h->hash);
  LRUHandle* old = *ptr;
  h->next_hash = (old == nullptr ? nullptr : old->next_hash);
  *ptr = h;
  if (old == nullptr) {
    ++elems_;
    if ((elems_ >> length_bits_) > 0) {  // elems_ >= length
      // Since each cache entry is fairly large, we aim for a small
      // average linked list length (<= 1).
      Resize();
    }
  }
  return old;
}

LRUHandle* LRUHandleTable::Remove(const Slice& key, uint32_t hash) {
  LRUHandle** ptr = FindPointer(key, hash);
  LRUHandle* result = *ptr;
  if (result != nullptr) {
    *ptr = result->next_hash;
    --elems_;
  }
  return result;
}

LRUHandle** LRUHandleTable::FindPointer(const Slice& key, uint32_t hash) {
  //length_bits is lower, shard bits is higher.
  LRUHandle** ptr = &list_[hash >> (32 - length_bits_)];
  //and this is done when collision
  while (*ptr != nullptr && ((*ptr)->hash != hash || key != (*ptr)->key())) {
    ptr = &(*ptr)->next_hash;
  }
  return ptr;
}

void LRUHandleTable::Resize() {
  if (length_bits_ >= max_length_bits_) {
    // Due to reaching limit of hash information, if we made the table
    // bigger, we would allocate more addresses but only the same
    // number would be used.
    return;
  }
  if (length_bits_ >= 31) {
    // Avoid undefined behavior shifting uint32_t by 32
    return;
  }

  uint32_t old_length = uint32_t{1} << length_bits_;
  int new_length_bits = length_bits_ + 1;
  std::unique_ptr<LRUHandle* []> new_list {
    new LRUHandle* [size_t{1} << new_length_bits] {}
  };
  uint32_t count = 0;
  for (uint32_t i = 0; i < old_length; i++) {
    LRUHandle* h = list_[i];
    while (h != nullptr) {
      LRUHandle* next = h->next_hash;
      uint32_t hash = h->hash;
      LRUHandle** ptr = &new_list[hash >> (32 - new_length_bits)];
      h->next_hash = *ptr;
      *ptr = h;
      h = next;
      count++;
    }
  }
  assert(elems_ == count);
  list_ = std::move(new_list);
  length_bits_ = new_length_bits;
}

CBHTable::CBHTable(int max_upper_hash_bits)
    : elems_(0),
      length_bits_(CBHTbitlength),
      list_(new LRUHandle* [size_t{1} << length_bits_] {}),
      max_length_bits_(max_upper_hash_bits) {
        //for DCA ref pool
        //we don't want destructor to be called while accessing ref pool,
        //so we use malloc.
        ////[slot availability check], [actual ref slots]
        DCA_ref_pool = (int*)calloc(((size_t{1} << CBHTbitlength) * threadcount)
         + (size_t{1} << CBHTbitlength), sizeof(int));
        stampincr = 0;
        availindex = (size_t{1} << CBHTbitlength) * threadcount;
      }

CBHTable::~CBHTable() {
  //CBHT entries are linked to HT. dont free them here.
}

LRUHandle* CBHTable::Lookup(const Slice& key, uint32_t hash) {
  LRUHandle* ptr = *FindPointer(key, hash);
  if(ptr != nullptr){
    //since its not protected by write lock,
    //there is a slight chance that the entry may have been de-DCAed.
    int stamptmp = ptr->DCAstamp;
    int stamptmp_tc = stamptmp * threadcount;
    if(stamptmp > -1 && stamptmp < (int)(size_t{1} << length_bits_)){
      DCA_ref_pool[stamptmp_tc + getmytid()]++;
    }
  }
  return ptr;
}

//this replaces to new entry from old entry via same key, and returns old one?
LRUHandle* CBHTable::Insert(LRUHandle* h, bool reverse) {

  //continue
  LRUHandle** ptr = FindPointer(h->key(), h->hash);
  LRUHandle* old = *ptr;
  h->next_hash_cbht = (old == nullptr ? nullptr : old->next_hash_cbht);
  *ptr = h;

  if(old == nullptr){
    ++elems_;
    //start eviction if table is half full
    //evict 1 at 33, not 32.
    if ((elems_ >> (length_bits_ - 1)) > 0) {  // elems_ >= length / 2
      //remove one entry from DCA
      LRUHandle* rete = EvictFIFO();
      if(rete == nullptr){
        //failed
        insertblocked++;
        return h;
      }
    }
    if(reverse){
      //for insignificant prefetched entries
      hashkeylist.push_front(std::make_pair(h->key(), h->hash));  
    }
    else{
      hashkeylist.push_back(std::make_pair(h->key(), h->hash));
    }
  }
  
  h->indca = true;
  
  //get stamp
  uint32_t stamptmp = 0;
  uint32_t looped = 0;
  uint32_t i = stampincr;
  while(looped < (size_t{1} << length_bits_)){
    i++;
    looped++;
    if(i >= (size_t{1} << length_bits_)){
      i = 0;
    }
    if(DCA_ref_pool[availindex + i] == 0){
      DCA_ref_pool[availindex + i] = 1;
      stamptmp = i;
      stampincr = i;  //next suggestion for faster search
      break;
    }
  }
  
  //if(Shard(h->hash) == 4) printf("looped: %d\ti: %d\n", looped, i);
  h->DCAstamp = stamptmp;
  h->DCAstamp_tc = stamptmp * threadcount;


  /*
  may return:
  -evicted entry (h was inserted. must LRU_Insert this outside)
  -nullptr (h was inserted)
  -insert entry itself (insertblocked)
  */
  return old;
}

LRUHandle* CBHTable::Remove(const Slice& key, uint32_t hash, bool dontforce) {
  LRUHandle** ptr = FindPointer(key, hash);
  LRUHandle* result = *ptr;
  if (result != nullptr) {
    //backup stamp before init
    int stamptmp = result->DCAstamp;
    int stamptmp_tc = stamptmp * threadcount;
    //sanity check
    if(stamptmp > -1 && stamptmp < (int)(size_t{1} << length_bits_)){
      int refstmp = 0;
      for(uint32_t i = 0; i < threadcount; i++){
        refstmp += DCA_ref_pool[stamptmp_tc + i];
        if(!dontforce) DCA_ref_pool[stamptmp_tc + i] = 0; //zero
      }
      //don't force. return nullptr if it is still referenced.
      if(dontforce){
        if(refstmp != 0){
          return nullptr;
        }
      }
      //otherwise...
      if((int)result->refs + refstmp < 0){
        result->refs = 0;
      }
      else{
        result->refs += refstmp;
      }
      result->DCAstamp = -1;
      DCA_ref_pool[availindex + stamptmp] = 0;

      result->indca = false;
      result->indcafreq = 0;
      //remove from dca
      *ptr = result->next_hash_cbht;
      --elems_;
    }
  }
  return result;
}

void CBHTable::Unref(LRUHandle *e){
  //since its not protected by write lock,
  //there is a slight chance that the entry may have been de-DCAed.
  int stamptmp = e->DCAstamp;
  int stamptmp_tc = stamptmp * threadcount;
  if(stamptmp > -1 && stamptmp < (int)(size_t{1} << length_bits_)){
    DCA_ref_pool[stamptmp_tc + getmytid()]--;
  }
}

LRUHandle** CBHTable::FindPointer(const Slice& key, uint32_t hash) {
  //length_bits is lower, shard bits is higher.
  LRUHandle** ptr = &list_[hash >> (32 - length_bits_)];
  //and this is done when collision
  while (*ptr != nullptr && ((*ptr)->hash != hash || key != (*ptr)->key())) {
    ptr = &(*ptr)->next_hash_cbht;
  }
  return ptr;
}

struct greater{
  bool operator()(const LRUHandle* a, const LRUHandle* b) const{
      return a->indcafreq > b->indcafreq;
  }
};

//loose LRU garbage collector for DCA
void CBHTable::LRU_GC(){
  LRUHandle* e = nullptr;
  LRUHandle* min = nullptr;
  LRUHandle* result = nullptr;
  //copy list to temp list, as well as cleanup list
  auto iter = hashkeylist.begin();
  while(iter != hashkeylist.end()){
    e = Lookup(iter->first, iter->second);
    if(e != nullptr){
      hashkeytemp.push_back(e);
      std::push_heap(hashkeytemp.begin(), hashkeytemp.end(), greater());
      iter++;
    }
    else{
      //remove as it doesnt exist
      iter = hashkeylist.erase(iter);
    }
  }

  //LRU based eviction
  uint64_t hardlimit = (size_t{1} << (length_bits_ - 1)) * DCAclear_rate / 100;

  while(!hashkeytemp.empty() && hardlimit-- > 0){ 
    std::pop_heap(hashkeytemp.begin(), hashkeytemp.end(), greater());
    min = hashkeytemp.back();
    hashkeytemp.pop_back();
    result = Remove(min->key(), min->hash, true);
    if(result != nullptr){  //remove successful
      evictedfromclear++;
      DCA_evicted_list.push_back(min);
    }
  }

  //reset temp list
  hashkeytemp.clear();
}

//only for evicting single element
LRUHandle* CBHTable::EvictFIFO(){
  std::pair<Slice, uint32_t> temp;
  LRUHandle* e = nullptr;
  LRUHandle* result = nullptr;
  int hardlimit = size_t{1} << (length_bits_ - 1);
  //avoid looping indefinitely
  while(!hashkeylist.empty() && hardlimit-- > 0){
    temp = hashkeylist.front();
    hashkeylist.pop_front();
    e = Lookup(temp.first, temp.second);
    if(e != nullptr){
      result = Remove(temp.first, temp.second, true);  //true: dont force remove
      if(result == nullptr){  //remove couldnt remove it because it is referenced.
        hashkeylist.push_back(temp);  //insert it back
      }
    }
    if(result != nullptr){  //we will loop until we get one result.
      evictedcount++;
      break;  //do only one eviction
    }
    //continue if the eviction was invalid(entry didnt exist)
  }
  return result;
}

bool CBHTable::IsTableFull(){
  if ((elems_ >> (length_bits_ - 1)) > 0) {  // elems_ >= length / 2
    return true;
  }
  else return false;
}

void CBHTable::beforeWriteLock(uint32_t& hash){
  lockedhash = hash;
  locked = true;
}

void CBHTable::afterWriteLock(){
  locked = false;
}

void CBHTable::beforeMasterLock(){
  masterlocked = true;
}

void CBHTable::afterMasterLock(){
  masterlocked = false;
}

bool CBHTable::beforeReadLock(uint32_t& hash){
  /*
    return true if readlock is required
    return false if bypassing is allowed
  */
  if(!masterlocked && (!locked || lockedhash != hash)){
    return false;
  }
  return true;
}

LRUCacheShard::LRUCacheShard(
    size_t capacity, bool strict_capacity_limit, double high_pri_pool_ratio,
    bool use_adaptive_mutex, CacheMetadataChargePolicy metadata_charge_policy,
    int max_upper_hash_bits,
    const std::shared_ptr<SecondaryCache>& secondary_cache)
    : capacity_(0),
      high_pri_pool_usage_(0),
      strict_capacity_limit_(strict_capacity_limit),
      high_pri_pool_ratio_(high_pri_pool_ratio),
      high_pri_pool_capacity_(0),
      table_(max_upper_hash_bits),
      cbhtable_(max_upper_hash_bits),
      usage_(0),
      lru_usage_(0),
      mutex_(use_adaptive_mutex),
      secondary_cache_(secondary_cache) {
  set_metadata_charge_policy(metadata_charge_policy);
  // Make empty circular linked list
  lru_.next = &lru_;
  lru_.prev = &lru_;
  lru_low_pri_ = &lru_;
  SetCapacity(capacity);
  // ptr of lru head
  cbhtable_.lru_ = &lru_;
}

void LRUCacheShard::EraseUnRefEntries() {
  autovector<LRUHandle*> last_reference_list;
  {
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    while (lru_.next != &lru_) {
      LRUHandle* old = lru_.next;
      // LRU list contains only elements which can be evicted
      assert(old->InCache() && !old->HasRefs());

      LRU_Remove(old);
      table_.Remove(old->key(), old->hash);
      if(CBHTturnoff){  //if turnoff is 0, always disable CBHT
        if(old->indca){
          WriteLock wl(&rwmutex_);
          if(old->indca){
            if(cbhtable_.Remove(old->key(), old->hash) != nullptr){
              invalidatedcount++;
            }
          }
        }
      }
      
      old->SetInCache(false);
      size_t total_charge = old->CalcTotalCharge(metadata_charge_policy_);
      assert(usage_ >= total_charge);
      usage_ -= total_charge;
      last_reference_list.push_back(old);
    }
  }

  for (auto entry : last_reference_list) {
    entry->Free();
    freecount_eraseunref++;
  }
}

void LRUCacheShard::ApplyToSomeEntries(
    const std::function<void(const Slice& key, void* value, size_t charge,
                             DeleterFn deleter)>& callback,
    uint32_t average_entries_per_lock, uint32_t* state) {
  // The state is essentially going to be the starting hash, which works
  // nicely even if we resize between calls because we use upper-most
  // hash bits for table indexes.
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  uint32_t length_bits = table_.GetLengthBits();
  uint32_t length = uint32_t{1} << length_bits;

  assert(average_entries_per_lock > 0);
  // Assuming we are called with same average_entries_per_lock repeatedly,
  // this simplifies some logic (index_end will not overflow)
  assert(average_entries_per_lock < length || *state == 0);

  uint32_t index_begin = *state >> (32 - length_bits);
  uint32_t index_end = index_begin + average_entries_per_lock;
  if (index_end >= length) {
    // Going to end
    index_end = length;
    *state = UINT32_MAX;
  } else {
    *state = index_end << (32 - length_bits);
  }

  table_.ApplyToEntriesRange(
      [callback](LRUHandle* h) {
        DeleterFn deleter = h->IsSecondaryCacheCompatible()
                                ? h->info_.helper->del_cb
                                : h->info_.deleter;
        callback(h->key(), h->value, h->charge, deleter);
      },
      index_begin, index_end);
}

void LRUCacheShard::TEST_GetLRUList(LRUHandle** lru, LRUHandle** lru_low_pri) {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  *lru = &lru_;
  *lru_low_pri = lru_low_pri_;
}

size_t LRUCacheShard::TEST_GetLRUSize() {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  LRUHandle* lru_handle = lru_.next;
  size_t lru_size = 0;
  while (lru_handle != &lru_) {
    lru_size++;
    lru_handle = lru_handle->next;
  }
  return lru_size;
}

double LRUCacheShard::GetHighPriPoolRatio() {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  return high_pri_pool_ratio_;
}

void LRUCacheShard::LRU_Remove(LRUHandle* e) {
  //return if its already been removed from lru
  if(e->next == nullptr || e->prev == nullptr) return;
  //assert(e->next != nullptr);
  //assert(e->prev != nullptr);
  if (lru_low_pri_ == e) {
    lru_low_pri_ = e->prev;
  }
  e->next->prev = e->prev;
  e->prev->next = e->next;
  e->prev = e->next = nullptr;
  size_t total_charge = e->CalcTotalCharge(metadata_charge_policy_);
  assert(lru_usage_ >= total_charge);
  lru_usage_ -= total_charge;
  if (e->InHighPriPool()) {
    assert(high_pri_pool_usage_ >= total_charge);
    high_pri_pool_usage_ -= total_charge;
  }
}

void LRUCacheShard::LRU_Insert(LRUHandle* e) {
  //return if its already inside lru
  if(e->next != nullptr || e->prev != nullptr) return;
  //assert(e->next == nullptr);
  //assert(e->prev == nullptr);
  size_t total_charge = e->CalcTotalCharge(metadata_charge_policy_);
  if (high_pri_pool_ratio_ > 0 && (e->IsHighPri() || e->HasHit())) {
    // Inset "e" to head of LRU list.
    e->next = &lru_;
    e->prev = lru_.prev;
    e->prev->next = e;
    e->next->prev = e;
    e->SetInHighPriPool(true);
    high_pri_pool_usage_ += total_charge;
    MaintainPoolSize();
  } else {
    // Insert "e" to the head of low-pri pool. Note that when
    // high_pri_pool_ratio is 0, head of low-pri pool is also head of LRU list.
    e->next = lru_low_pri_->next;
    e->prev = lru_low_pri_;
    e->prev->next = e;
    e->next->prev = e;
    e->SetInHighPriPool(false);
    lru_low_pri_ = e;
  }
  lru_usage_ += total_charge;
}

void LRUCacheShard::MaintainPoolSize() {
  while (high_pri_pool_usage_ > high_pri_pool_capacity_) {
    // Overflow last entry in high-pri pool to low-pri pool.
    lru_low_pri_ = lru_low_pri_->next;
    assert(lru_low_pri_ != &lru_);
    lru_low_pri_->SetInHighPriPool(false);
    size_t total_charge =
        lru_low_pri_->CalcTotalCharge(metadata_charge_policy_);
    assert(high_pri_pool_usage_ >= total_charge);
    high_pri_pool_usage_ -= total_charge;
  }
}

void LRUCacheShard::EvictFromLRU(size_t charge,
                                 autovector<LRUHandle*>* deleted) {
  while ((usage_ + charge) > capacity_ && lru_.next != &lru_) {
    evictedfromlrucount++;
    LRUHandle* old = lru_.next;
    // LRU list contains only elements which can be evicted
    assert(old->InCache() && !old->HasRefs());

    LRU_Remove(old);
    if(CBHTturnoff){  //if turnoff is 0, always disable CBHT
      if(old->indca){
        WriteLock wl(&rwmutex_);
        if(old->indca){
          if(cbhtable_.Remove(old->key(), old->hash) != nullptr){
            invalidatedcount++;
          }
        }
      }
    }
    table_.Remove(old->key(), old->hash);

    old->SetInCache(false);
    size_t old_total_charge = old->CalcTotalCharge(metadata_charge_policy_);
    assert(usage_ >= old_total_charge);
    usage_ -= old_total_charge;
    deleted->push_back(old);
  }
}

void LRUCacheShard::SetCapacity(size_t capacity) {
  autovector<LRUHandle*> last_reference_list;
  {
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    capacity_ = capacity;
    high_pri_pool_capacity_ = capacity_ * high_pri_pool_ratio_;
    EvictFromLRU(0, &last_reference_list);
  }

  // Try to insert the evicted entries into tiered cache
  // Free the entries outside of mutex for performance reasons
  for (auto entry : last_reference_list) {
    if (secondary_cache_ && entry->IsSecondaryCacheCompatible() &&
        !entry->IsPromoted()) {
      secondary_cache_->Insert(entry->key(), entry->value, entry->info_.helper)
          .PermitUncheckedError();
    }
    entry->Free();
    freecount_setcapacity++;
  }
}

void LRUCacheShard::SetStrictCapacityLimit(bool strict_capacity_limit) {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  strict_capacity_limit_ = strict_capacity_limit;
}

Status LRUCacheShard::InsertItem(LRUHandle* e, Cache::Handle** handle,
                                 bool free_handle_on_fail) {
  Status s = Status::OK();
  autovector<LRUHandle*> last_reference_list;
  size_t total_charge = e->CalcTotalCharge(metadata_charge_policy_);

  {
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));

    // Free the space following strict LRU policy until enough space
    // is freed or the lru list is empty
    EvictFromLRU(total_charge, &last_reference_list);


    if ((usage_ + total_charge) > capacity_ &&
        (strict_capacity_limit_ || handle == nullptr)) {
      e->SetInCache(false);
      if (handle == nullptr) {
        // Don't insert the entry but still return ok, as if the entry inserted
        // into cache and get evicted immediately.
        last_reference_list.push_back(e);
      } else {
        if (free_handle_on_fail) {
          delete[] reinterpret_cast<char*>(e);
          *handle = nullptr;
        }
        s = Status::Incomplete("Insert failed due to LRU cache being full.");
      }
    } else {
      // Insert into the cache. Note that the cache might get larger than its
      // capacity if not enough space was freed up.
      LRUHandle* old = table_.Insert(e);
      usage_ += total_charge;
      if (old != nullptr) {
        s = Status::OkOverwritten();
        assert(old->InCache());
        old->SetInCache(false);
        if (!old->HasRefs()) {
          // old is on LRU because it's in cache and its reference count is 0
          LRU_Remove(old);
          size_t old_total_charge =
              old->CalcTotalCharge(metadata_charge_policy_);
          assert(usage_ >= old_total_charge);
          usage_ -= old_total_charge;
          last_reference_list.push_back(old);
          //remove the entry from dca
          if(CBHTturnoff){  //if turnoff is 0, always disable CBHT
            cbhtable_.insertcount++;
            if(old->indca){
              cbhtable_.beforeWriteLock(e->hash);
              WriteLock wl(&rwmutex_);
              if(old->indca){
                //update to the new entry
                if(cbhtable_.Lookup(e->key(), e->hash) != nullptr){
                  cbhtable_.Insert(e);
                  invalidatedcount++;
                }
              }
              cbhtable_.afterWriteLock();
            }
          }
        }
      }
      if (handle == nullptr) {
        LRU_Insert(e);
      } else {
        e->Ref();
        *handle = reinterpret_cast<Cache::Handle*>(e);
      }
    }
  }

  // Try to insert the evicted entries into the secondary cache
  // Free the entries here outside of mutex for performance reasons
  for (auto entry : last_reference_list) {
    if (secondary_cache_ && entry->IsSecondaryCacheCompatible() &&
        !entry->IsPromoted()) {
      secondary_cache_->Insert(entry->key(), entry->value, entry->info_.helper)
          .PermitUncheckedError();
    }
    entry->Free();
    freecount_insertitem++;
  }
  return s;
}

void LRUCacheShard::Promote(LRUHandle* e) {
  SecondaryCacheResultHandle* secondary_handle = e->sec_handle;

  assert(secondary_handle->IsReady());
  e->SetIncomplete(false);
  e->SetInCache(true);
  e->SetPromoted(true);
  e->value = secondary_handle->Value();
  e->charge = secondary_handle->Size();
  delete secondary_handle;

  // This call could fail if the cache is over capacity and
  // strict_capacity_limit_ is true. In such a case, we don't want
  // InsertItem() to free the handle, since the item is already in memory
  // and the caller will most likely just read from disk if we erase it here.
  if (e->value) {
    Cache::Handle* handle = reinterpret_cast<Cache::Handle*>(e);
    Status s = InsertItem(e, &handle, /*free_handle_on_fail=*/false);
    if (s.ok()) {
      // InsertItem would have taken a reference on the item, so decrement it
      // here as we expect the caller to already hold a reference
      e->Unref();
    } else {
      // Item is in memory, but not accounted against the cache capacity.
      // When the handle is released, the item should get deleted
      assert(!e->InCache());
    }
  } else {
    // Since the secondary cache lookup failed, mark the item as not in cache
    // Don't charge the cache as its only metadata that'll shortly be released
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    e->charge = 0;
    e->SetInCache(false);
  }
}

//find median
int cmpfunc(const void* a, const void* b){
  return (*(int*)a - *(int*)b);
}

void copyAndSort(){

  //copy to sortarr
  for(uint32_t i = 0; i < shardnumlimit * PADDING; i += PADDING){
    sortarr[i] = hitrate[i];
  }
  //get median
  qsort(sortarr, shardnumlimit, sizeof(int), cmpfunc);
  //calc global median
  //instead of just picking median, add and divide.
  //this is to make sure skip still happens when all shards are low hitrate.
  //CBHTturnoff is a suggested percentage for picking median
  skip_median = (sortarr[(shardnumlimit - 1) * CBHTturnoff / 100]
   + CBHTturnoff) / 2;
  //skip_median = CBHTturnoff;

  detected_skew = sortarr[(shardnumlimit - 1) * PADDING] - sortarr[0];

}

// CBHT is allocated per shard, not as standalone
Cache::Handle* LRUCacheShard::Lookup(
    const Slice& key, uint32_t hash,
    const ShardedCache::CacheItemHelper* helper,
    const ShardedCache::CreateCallback& create_cb, Cache::Priority priority,
    bool wait, Statistics* stats) {
  LRUHandle* e = nullptr;
  { 
    /*
    struct timespec telapsed = {0, 0};
    struct timespec tstart = {0, 0}, tend = {0, 0};

    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &tstart);
*/
    /*
    //time to print out important stats
    time_t elapsed = (tstart.tv_sec - inittime) / 10;
    if(elapsed != prevtime){
      prevtime = elapsed;
      printf("%ld seconds in, pinned_usage: %lld%%, lru_usage: %lld%%, total: %lld%%\n", elapsed, ((long long)usage_ - (long long)lru_usage_) * 100 / (long long)capacity_, (long long)lru_usage_ * 100 / (long long)capacity_, (long long)usage_ * 100 / (long long)capacity_);
    }
    //important stats end
    */
    uint32_t hashshard = Shard(hash) * PADDING; //add cacheline padding.
    
    //if turnoff is 0, always disable CBHT. if 100, always have it enabled
    if(CBHTturnoff){
      cbhtable_.lookupcount++;
      
      //negative cache check
      //if it doesnt exist in the LRU cache, it doesnt exist in the DCA anyway.
      /*
      e = table_.Lookup(key, hash);
      if(e == nullptr){
        return nullptr;
      }
      */
      if(CBHTState[hashshard] || CBHTturnoff == 100)
      {
        if(cbhtable_.beforeReadLock(hash)){
          rwmutex_.ReadLock();
        }
        else{
          readlockbypass[hashshard]++;
        }
        e = cbhtable_.Lookup(key, hash);
        totalhit[hashshard]++;
        if(e != nullptr){
          e->SetHit();
          e->indcafreq = cbhtable_.accessstamp++;

          /*
          clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &tend);
          telapsed.tv_sec += (tend.tv_sec - tstart.tv_sec);
          telapsed.tv_nsec += (tend.tv_nsec - tstart.tv_nsec);
          time_t telapsedtotal = telapsed.tv_sec * 1000000000 + telapsed.tv_nsec;
          shardtotaltime[hashshard] += telapsedtotal;
          shardlasttime[hashshard] = tend.tv_sec * 1000000000 + tend.tv_nsec;
          */
          rwmutex_.ReadUnlock();
          return reinterpret_cast<Cache::Handle*>(e);
        }
        else{
          nohit[hashshard]++;
          if((CBHTturnoff != 100)&&(nohit[hashshard] > Nsupple[hashshard])){
            CBHTState[hashshard] = 0;
          }
        }
      }
      rwmutex_.ReadUnlock();
    }
   
  
    //vanilla path
    
    if(lockheld[hashshard]) lookupblockcount[hashshard]++;
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    
    e = table_.Lookup(key, hash);

    //sanity check
    if (e != nullptr) {
      e->SetHit();

      //identify DCA hitrate without actually using DCA
      virtual_totalhit[hashshard]++;
      if(!e->indca) virtual_nohit[hashshard]++;

      assert(e->InCache());
      // The entry is in LRU since it's in hash and has no external references
      LRU_Remove(e);

      //dont change state if the entry is a part of dca.
      e->Ref();

      if(CBHTturnoff){  //if turnoff hitrate is 0, always disable DCA
        //count to N
        N[hashshard]++;
        int NLIMITtmp = NLIMIT[hashshard];  //no change
        uint64_t nlimtmp = cbhtable_.lookupcount * 100 / (cbhtable_.lookupcount + cbhtable_.insertcount);
        if(nlimtmp > 10){
          NLIMITtmp = NLIMITtmp * (int)nlimtmp / 100;
        }
        else{ //low bound
          NLIMITtmp = NLIMITtmp * 10 / 100;
        }
        NLIMIT_N[hashshard] = nlimtmp;  //for telemetry

        if(N[hashshard] > NLIMITtmp){
          cbhtable_.beforeMasterLock();
          WriteLock wl(&rwmutex_);
          if(N[hashshard] > NLIMITtmp){
            N[hashshard] = 0;

            LRUHandle* temp = e;
            //hitrate telemetry
            int misscount = nohit[hashshard] + virtual_nohit[hashshard];
            int totalcount = totalhit[hashshard] + virtual_totalhit[hashshard];
            if(totalcount > 100){
              hitrate[hashshard] = 100 - (misscount * 100 / totalcount);
            }
            
            //get median from all of DCA shards
            copyAndSort();
            //calculate next dca skip
            Nsupple[hashshard] = NLIMITtmp * skip_median / 100;
           /*
            //remove some entries from DCA when pinned usage is too high
            while(((usage_ - lru_usage_) * 100 / capacity_) > DCAsizelimit){
              LRUHandle* rete = cbhtable_.EvictFIFO();
              if(rete == nullptr){
                //no more to evict
                break;
              }
              else{
                //put it back in LRU Cache
                LRU_Insert(rete);
              }
            }
            */
            //DCAskip_hit[hashshard] += hitrate;
            //DCAskip_n[hashshard]++;
            if(DCAclear_rate > 0){
              cbhtable_.LRU_GC();
              for(auto elem : cbhtable_.DCA_evicted_list){
                LRU_Insert(elem);
              }
              evictmiddlecount[hashshard] += cbhtable_.DCA_evicted_list.size();
              cbhtable_.DCA_evicted_list.clear();
            }

            LRUHandle* rete = cbhtable_.Insert(temp);
            if(rete != nullptr && rete != temp){
              LRU_Insert(rete);
            }
            called++;
            temp = lru_.prev;
            //fill the rest of the table that is emptied by invalidated entries
            LRUHandle* temp2 = nullptr;

            if(DCAprefetch == true){
              int i = 0;
              //fill only NLIMIT amount, because we only touched those amount.
              //prefetching more doesnt make sense.
              //dont fill if LRU empty or pinned usage over half
              //dont care if DCA table is full, always DCA insert so to make
              //sure DCA has the hottest entries.
              while (lru_.next != &lru_ && (((usage_ - lru_usage_) * 100 / 
              capacity_) < DCAsizelimit) && (i < NLIMITtmp)){
                i++;
                temp2 = temp->prev;
                LRU_Remove(temp); //keep all dca entries out of lru
                rete = cbhtable_.Insert(temp, true); //prefetched entries shall be evicted first
                if(rete != nullptr && rete != temp){
                  LRU_Insert(rete);
                }
                temp = temp2;
              }
              if(i > 0) called_refill++;
            }
            
            nohit[hashshard] = 0;
            totalhit[hashshard] = 0;
            readlockbypass[hashshard] = 0;
            virtual_nohit[hashshard] = 0;
            virtual_totalhit[hashshard] = 0;
            CBHTState[hashshard] = 1; //re-enable DCA
            DCAentrycount[hashshard] = cbhtable_.elems_;
          }
          cbhtable_.afterMasterLock();
        }
      }
    }
    shardaccesscount[hashshard] += 1;

    /*
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &tend);
    telapsed.tv_sec += (tend.tv_sec - tstart.tv_sec);
    telapsed.tv_nsec += (tend.tv_nsec - tstart.tv_nsec);
    time_t telapsedtotal = telapsed.tv_sec * 1000000000 + telapsed.tv_nsec;
    shardtotaltime[hashshard] += telapsedtotal;
    shardlasttime[hashshard] = tend.tv_sec * 1000000000 + tend.tv_nsec;
    */
  }

  // If handle table lookup failed, then allocate a handle outside the
  // mutex if we're going to lookup in the secondary cache
  // Only support synchronous for now
  // TODO: Support asynchronous lookup in secondary cache
  if (!e && secondary_cache_ && helper && helper->saveto_cb) {
    // For objects from the secondary cache, we expect the caller to provide
    // a way to create/delete the primary cache object. The only case where
    // a deleter would not be required is for dummy entries inserted for
    // accounting purposes, which we won't demote to the secondary cache
    // anyway.
    assert(create_cb && helper->del_cb);
    std::unique_ptr<SecondaryCacheResultHandle> secondary_handle =
        secondary_cache_->Lookup(key, create_cb, wait);
    if (secondary_handle != nullptr) {
      e = reinterpret_cast<LRUHandle*>(
          new char[sizeof(LRUHandle) - 1 + key.size()]);

      e->flags = 0;
      e->SetSecondaryCacheCompatible(true);
      e->info_.helper = helper;
      e->key_length = key.size();
      e->hash = hash;
      e->refs = 0;
      e->next = e->prev = nullptr;
      e->SetPriority(priority);
      memcpy(e->key_data, key.data(), key.size());
      e->value = nullptr;
      e->sec_handle = secondary_handle.release();
      e->Ref();

      if (wait) {
        Promote(e);
        if (!e->value) {
          // The secondary cache returned a handle, but the lookup failed
          e->Unref();
          e->Free();
          freecount_secondarycache++;
          e = nullptr;
        } else {
          PERF_COUNTER_ADD(secondary_cache_hit_count, 1);
          RecordTick(stats, SECONDARY_CACHE_HITS);
        }
      } else {
        // If wait is false, we always return a handle and let the caller
        // release the handle after checking for success or failure
        e->SetIncomplete(true);
        // This may be slightly inaccurate, if the lookup eventually fails.
        // But the probability is very low.
        PERF_COUNTER_ADD(secondary_cache_hit_count, 1);
        RecordTick(stats, SECONDARY_CACHE_HITS);
      }
    }
  }
  return reinterpret_cast<Cache::Handle*>(e);
}

bool LRUCacheShard::Ref(Cache::Handle* h) {
  LRUHandle* e = reinterpret_cast<LRUHandle*>(h);
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  // To create another reference - entry must be already externally referenced
  assert(e->HasRefs());
  e->Ref();
  return true;
}

void LRUCacheShard::SetHighPriorityPoolRatio(double high_pri_pool_ratio) {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  high_pri_pool_ratio_ = high_pri_pool_ratio;
  high_pri_pool_capacity_ = capacity_ * high_pri_pool_ratio_;
  MaintainPoolSize();
}

bool LRUCacheShard::Release(Cache::Handle* handle, bool force_erase) {
  if (handle == nullptr) {
    return false;
  }
  LRUHandle* e = reinterpret_cast<LRUHandle*>(handle);

  if(CBHTturnoff) {
    if(e->indca) {
      cbhtable_.Unref(e);
      return true;  //never release dca items
    }
  }
  bool last_reference = false;
  {
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    if(CBHTturnoff) {
      if(e->indca) {
        cbhtable_.Unref(e);
        return true;  //never release dca items
      }
    }

    last_reference = e->Unref();
    if (last_reference && e->InCache()) {
      // The item is still in cache, and nobody else holds a reference to it

      if (usage_ > capacity_ || force_erase) {
              
        // The LRU list must be empty since the cache is full
        assert(lru_.next == &lru_ || force_erase);
        
        // Take this opportunity and remove the item
        table_.Remove(e->key(), e->hash);
        e->SetInCache(false);
        
      } else {
        // Put the item back on the LRU list, and don't free it
        LRU_Insert(e);
        last_reference = false;
      }
    }
    // If it was the last reference, and the entry is either not secondary
    // cache compatible (i.e a dummy entry for accounting), or is secondary
    // cache compatible and has a non-null value, then decrement the cache
    // usage. If value is null in the latter case, taht means the lookup
    // failed and we didn't charge the cache.
    if (last_reference && (!e->IsSecondaryCacheCompatible() || e->value)) {
      size_t total_charge = e->CalcTotalCharge(metadata_charge_policy_);
      assert(usage_ >= total_charge);
      usage_ -= total_charge;
    }
  }

  // Free the entry here outside of mutex for performance reasons
  //crashes here
  if (last_reference) {
    e->Free();
    freecount_release++;
  }
  return last_reference;
}

Status LRUCacheShard::Insert(const Slice& key, uint32_t hash, void* value,
                             size_t charge,
                             void (*deleter)(const Slice& key, void* value),
                             const Cache::CacheItemHelper* helper,
                             Cache::Handle** handle, Cache::Priority priority) {
  // Allocate the memory here outside of the mutex
  // If the cache is full, we'll have to release it
  // It shouldn't happen very often though.
  LRUHandle* e = reinterpret_cast<LRUHandle*>(
      new char[sizeof(LRUHandle) - 1 + key.size()]);

  e->value = value;
  e->flags = 0;
  if (helper) {
    e->SetSecondaryCacheCompatible(true);
    e->info_.helper = helper;
  } else {
#ifdef __SANITIZE_THREAD__
    e->is_secondary_cache_compatible_for_tsan = false;
#endif  // __SANITIZE_THREAD__
    e->info_.deleter = deleter;
  }
  e->charge = charge;
  e->key_length = key.size();
  e->hash = hash;
  e->refs = 0;
  e->next = e->prev = nullptr;
  e->SetInCache(true);
  e->SetPriority(priority);
  memcpy(e->key_data, key.data(), key.size());
  e->indca = false;
  e->indcafreq = 0;

  return InsertItem(e, handle, /* free_handle_on_fail */ true);
}

void LRUCacheShard::Erase(const Slice& key, uint32_t hash) {
  LRUHandle* e;
  bool last_reference = false;
  {
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    
    e = table_.Remove(key, hash);
    
    
    if (e != nullptr) {
      assert(e->InCache());
      e->SetInCache(false);
      if (!e->HasRefs()) {
        // The entry is in LRU since it's in hash and has no external references
        LRU_Remove(e);
        size_t total_charge = e->CalcTotalCharge(metadata_charge_policy_);
        assert(usage_ >= total_charge);
        usage_ -= total_charge;
        last_reference = true;
      }
      if(CBHTturnoff){  //if turnoff is 0, always disable CBHT
        if(e->indca){
          WriteLock wl(&rwmutex_);
          if(e->indca){
            if(cbhtable_.Remove(e->key(), e->hash) != nullptr){
              invalidatedcount++;
              last_reference = true; //free the dca entry.
            }
          }
        }
      }
    }
  }

  // Free the entry here outside of mutex for performance reasons
  // last_reference will only be true if e != nullptr
  if (last_reference) {
    e->Free();
    freecount_erase++;
  }
}

bool LRUCacheShard::IsReady(Cache::Handle* handle) {
  LRUHandle* e = reinterpret_cast<LRUHandle*>(handle);
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  bool ready = true;
  if (e->IsPending()) {
    assert(secondary_cache_);
    assert(e->sec_handle);
    ready = e->sec_handle->IsReady();
  }
  return ready;
}

size_t LRUCacheShard::GetUsage() const {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  return usage_;
}

size_t LRUCacheShard::GetPinnedUsage() const {
  MutexLock l(&mutex_);
  //Holdvalue hv(Shard(lru_.prev->hash));
  assert(usage_ >= lru_usage_);
  return usage_ - lru_usage_;
}

std::string LRUCacheShard::GetPrintableOptions() const {
  const int kBufferSize = 200;
  char buffer[kBufferSize];
  {
    MutexLock l(&mutex_);
    //Holdvalue hv(Shard(lru_.prev->hash));
    snprintf(buffer, kBufferSize, "    high_pri_pool_ratio: %.3lf\n",
             high_pri_pool_ratio_);
  }
  return std::string(buffer);
}

LRUCache::LRUCache(size_t capacity, int num_shard_bits,
                   bool strict_capacity_limit, double high_pri_pool_ratio,
                   std::shared_ptr<MemoryAllocator> allocator,
                   bool use_adaptive_mutex,
                   CacheMetadataChargePolicy metadata_charge_policy,
                   const std::shared_ptr<SecondaryCache>& secondary_cache)
    : ShardedCache(capacity, num_shard_bits, strict_capacity_limit,
                   std::move(allocator)) {
  num_shards_ = 1 << num_shard_bits;
  shards_ = reinterpret_cast<LRUCacheShard*>(
      port::cacheline_aligned_alloc(sizeof(LRUCacheShard) * num_shards_));
  size_t per_shard = (capacity + (num_shards_ - 1)) / num_shards_;
  for (int i = 0; i < num_shards_; i++) {
    new (&shards_[i]) LRUCacheShard(
        per_shard, strict_capacity_limit, high_pri_pool_ratio,
        use_adaptive_mutex, metadata_charge_policy,
        /* max_upper_hash_bits */ 32 - num_shard_bits, secondary_cache);
  }
  secondary_cache_ = secondary_cache;
}

LRUCache::~LRUCache() {
  if (shards_ != nullptr) {
    assert(num_shards_ > 0);
    for (int i = 0; i < num_shards_; i++) {
      shards_[i].~LRUCacheShard();
    }
    port::cacheline_aligned_free(shards_);
  }
}

CacheShard* LRUCache::GetShard(uint32_t shard) {
  return reinterpret_cast<CacheShard*>(&shards_[shard]);
}

const CacheShard* LRUCache::GetShard(uint32_t shard) const {
  return reinterpret_cast<CacheShard*>(&shards_[shard]);
}

void* LRUCache::Value(Handle* handle) {
  return reinterpret_cast<const LRUHandle*>(handle)->value;
}

size_t LRUCache::GetCharge(Handle* handle) const {
  return reinterpret_cast<const LRUHandle*>(handle)->charge;
}

Cache::DeleterFn LRUCache::GetDeleter(Handle* handle) const {
  auto h = reinterpret_cast<const LRUHandle*>(handle);
  if (h->IsSecondaryCacheCompatible()) {
    return h->info_.helper->del_cb;
  } else {
    return h->info_.deleter;
  }
}

uint32_t LRUCache::GetHash(Handle* handle) const {
  return reinterpret_cast<const LRUHandle*>(handle)->hash;
}

void LRUCache::DisownData() {
// Do not drop data if compile with ASAN to suppress leak warning.
#ifndef MUST_FREE_HEAP_ALLOCATIONS
  shards_ = nullptr;
  num_shards_ = 0;
#endif
}

size_t LRUCache::TEST_GetLRUSize() {
  size_t lru_size_of_all_shards = 0;
  for (int i = 0; i < num_shards_; i++) {
    lru_size_of_all_shards += shards_[i].TEST_GetLRUSize();
  }
  return lru_size_of_all_shards;
}

double LRUCache::GetHighPriPoolRatio() {
  double result = 0.0;
  if (num_shards_ > 0) {
    result = shards_[0].GetHighPriPoolRatio();
  }
  return result;
}

void LRUCache::WaitAll(std::vector<Handle*>& handles) {
  if (secondary_cache_) {
    std::vector<SecondaryCacheResultHandle*> sec_handles;
    sec_handles.reserve(handles.size());
    for (Handle* handle : handles) {
      if (!handle) {
        continue;
      }
      LRUHandle* lru_handle = reinterpret_cast<LRUHandle*>(handle);
      if (!lru_handle->IsPending()) {
        continue;
      }
      sec_handles.emplace_back(lru_handle->sec_handle);
    }
    secondary_cache_->WaitAll(sec_handles);
    for (Handle* handle : handles) {
      if (!handle) {
        continue;
      }
      LRUHandle* lru_handle = reinterpret_cast<LRUHandle*>(handle);
      if (!lru_handle->IsPending()) {
        continue;
      }
      uint32_t hash = GetHash(handle);
      LRUCacheShard* shard = static_cast<LRUCacheShard*>(GetShard(Shard(hash)));
      shard->Promote(lru_handle);
    }
  }
}

std::shared_ptr<Cache> NewLRUCache(
    size_t capacity, int num_shard_bits, bool strict_capacity_limit,
    double high_pri_pool_ratio,
    std::shared_ptr<MemoryAllocator> memory_allocator, bool use_adaptive_mutex,
    CacheMetadataChargePolicy metadata_charge_policy,
    const std::shared_ptr<SecondaryCache>& secondary_cache) {
  if (num_shard_bits >= 20) {
    return nullptr;  // the cache cannot be sharded into too many fine pieces
  }
  if (high_pri_pool_ratio < 0.0 || high_pri_pool_ratio > 1.0) {
    // invalid high_pri_pool_ratio
    return nullptr;
  }
  if (num_shard_bits < 0) {
    num_shard_bits = GetDefaultCacheShardBits(capacity);
  }
  return std::make_shared<LRUCache>(
      capacity, num_shard_bits, strict_capacity_limit, high_pri_pool_ratio,
      std::move(memory_allocator), use_adaptive_mutex, metadata_charge_policy,
      secondary_cache);
}

std::shared_ptr<Cache> NewLRUCache(const LRUCacheOptions& cache_opts) {
  return NewLRUCache(
      cache_opts.capacity, cache_opts.num_shard_bits,
      cache_opts.strict_capacity_limit, cache_opts.high_pri_pool_ratio,
      cache_opts.memory_allocator, cache_opts.use_adaptive_mutex,
      cache_opts.metadata_charge_policy, cache_opts.secondary_cache);
}

std::shared_ptr<Cache> NewLRUCache(
    size_t capacity, int num_shard_bits, bool strict_capacity_limit,
    double high_pri_pool_ratio,
    std::shared_ptr<MemoryAllocator> memory_allocator, bool use_adaptive_mutex,
    CacheMetadataChargePolicy metadata_charge_policy) {
  return NewLRUCache(capacity, num_shard_bits, strict_capacity_limit,
                     high_pri_pool_ratio, memory_allocator, use_adaptive_mutex,
                     metadata_charge_policy, nullptr);
}
}  // namespace ROCKSDB_NAMESPACE
