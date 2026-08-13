/// Feature tensor dimensions, ported 1:1 from ygo-agent `ygoinf/features.py`.
library;

const int nCardFeatures = 41;
const int maxCards = 80;
const int maxActions = 24;
const int nActionFeatures = 12;
const int nGlobalFeatures = 23;
const int nHistoryActions = 32;
const int hActionsFeats = 14;
const int nRnnChannels = 512;

const int descriptionLimit = 10000;
const int cardEffectOffset = 10010;
