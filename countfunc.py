import sys

filename = sys.argv[1]
fp = open(filename)
data = fp.read()
words = data.split()
fp.close()

wordfreq = {}
for word in words:
    if word not in wordfreq:
        wordfreq[word] = 0
    wordfreq[word] += 1

filename2 = sys.argv[2]
fp2 = open(filename2)
data2 = fp2.read()
words2 = data2.split()
fp2.close()

wordfreq2 = {}
for word2 in words2:
    if word2 not in wordfreq2:
        wordfreq2[word2] = 0
    wordfreq2[word2] += 1

percentage = {}
for word3 in wordfreq:
    if word3 in wordfreq2:
        percentage[word3] = round(float(wordfreq2[word3]) / float(wordfreq[word3]), 2)

print("percentage is traceB / traceA, so over 1 means traceB is larger")
for word in percentage:
    print(word, percentage[word])
