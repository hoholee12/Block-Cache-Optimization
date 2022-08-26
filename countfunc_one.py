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

for word in wordfreq:
    print(word, wordfreq[word])
