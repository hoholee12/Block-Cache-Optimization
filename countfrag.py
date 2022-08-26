import sys

filename = sys.argv[1]
fp = open(filename)
data = fp.read()
words = data.split()
fp.close()

wordfreq = {}
totalcount = 0
for word in words:
    totalcount += 1
    if word not in wordfreq:
        wordfreq[word] = 0
    wordfreq[word] += 1

for word2 in wordfreq:
    print("files fragmented in %s pieces: %d"%(word2, wordfreq[word2]))
print("total files: %d"%(totalcount))
try:
    print("%d%% fragmented"%(100 - (wordfreq["0"]+wordfreq["1"]) * 100 / totalcount))
except:
    try:
        print("%d%% fragmented"%(100 - (wordfreq["1"]) * 100 / totalcount))
    except:
        if totalcount > 0:
            print("100% fragmented")
        else:
            print("0% fragmented")