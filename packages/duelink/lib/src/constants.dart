// Protocol IDs — Client-to-Server
const int CTOS_RESPONSE = 1;
const int CTOS_UPDATE_DECK = 2;
const int CTOS_HAND_RESULT = 3;
const int CTOS_TP_RESULT = 4;
const int CTOS_PLAYER_INFO = 16;
const int CTOS_JOIN_GAME = 18;
const int CTOS_TIME_CONFIRM = 21;
const int CTOS_CHAT = 22;
const int CTOS_SURRENDER = 0x14;
const int CTOS_HS_TO_DUELIST = 32;
const int CTOS_HS_TO_OBSERVER = 33;
const int CTOS_HS_READY = 34;
const int CTOS_HS_NOT_READY = 35;
const int CTOS_HS_KICK = 36;
const int CTOS_HS_START = 37;

// Protocol IDs — Server-to-Client
const int STOC_GAME_MSG = 1;
const int STOC_ERROR_MSG = 2;
const int STOC_SELECT_HAND = 3;
const int STOC_SELECT_TP = 4;
const int STOC_HAND_RESULT = 5;
const int STOC_CHANGE_SIDE = 7;
const int STOC_WAITING_SIDE = 8;
const int STOC_DECK_COUNT = 9;
const int STOC_JOIN_GAME = 18;
const int STOC_TYPE_CHANGE = 19;
const int STOC_DUEL_START = 21;
const int STOC_DUEL_END = 22;
const int STOC_TIME_LIMIT = 24;
const int STOC_CHAT = 25;
const int STOC_HS_PLAYER_ENTER = 32;
const int STOC_HS_PLAYER_CHANGE = 33;
const int STOC_HS_WATCH_CHANGE = 34;

// Game Message sub-types
const int MSG_RESPONSE = 1;
const int MSG_HINT = 2;
const int MSG_WAITING = 3;
const int MSG_START = 4;
const int MSG_WIN = 5;
const int MSG_UPDATE_DATA = 6;
const int MSG_UPDATE_CARD = 7;
const int MSG_SELECT_BATTLE_CMD = 10;
const int MSG_SELECT_IDLE_CMD = 11;
const int MSG_SELECT_EFFECTYN = 12;
const int MSG_SELECT_YES_NO = 13;
const int MSG_SELECT_OPTION = 14;
const int MSG_SELECT_CARD = 15;
const int MSG_SELECT_CHAIN = 16;
const int MSG_SELECT_PLACE = 18;
const int MSG_SELECT_POSITION = 19;
const int MSG_SELECT_TRIBUTE = 20;
const int MSG_SELECT_COUNTER = 22;
const int MSG_SELECT_SUM = 23;
const int MSG_SELECT_DISFIELD = 24;
const int MSG_SORT_CARD = 25;
const int MSG_SELECT_UNSELECT_CARD = 26;
const int MSG_CONFIRM_CARDS = 30;
const int MSG_CONFIRM_DECKTOP = 31;
const int MSG_SHUFFLE_DECK = 32;
const int MSG_SHUFFLE_HAND = 33;
const int MSG_SWAP_GRAVE_DECK = 35;
const int MSG_SHUFFLE_SET_CARD = 36;
const int MSG_SHUFFLE_EXTRA = 39;
const int MSG_NEW_TURN = 40;
const int MSG_NEW_PHASE = 41;
const int MSG_MOVE = 50;
const int MSG_POS_CHANGE = 53;
const int MSG_SET = 54;
const int MSG_SWAP = 55;
const int MSG_FIELD_DISABLED = 56;
const int MSG_SUMMONING = 60;
const int MSG_SUMMONED = 61;
const int MSG_SP_SUMMONING = 62;
const int MSG_SP_SUMMONED = 63;
const int MSG_FLIP_SUMMONING = 64;
const int MSG_FLIP_SUMMONED = 65;
const int MSG_CHAINING = 70;
const int MSG_CHAIN_SOLVED = 73;
const int MSG_CHAIN_END = 74;
const int MSG_BECOME_TARGET = 83;
const int MSG_DRAW = 90;
const int MSG_DAMAGE = 91;
const int MSG_RECOVER = 92;
const int MSG_LP_UPDATE = 94;
const int MSG_PAY_LP_COST = 100;
const int MSG_ADD_COUNTER = 101;
const int MSG_REMOVE_COUNTER = 102;
const int MSG_ATTACK = 110;
const int MSG_ATTACK_DISABLE = 112;
const int MSG_TOSS_COIN = 130;
const int MSG_TOSS_DICE = 131;
const int MSG_ROCK_PAPER_SCISSORS = 132;
const int MSG_HAND_RES = 133;
const int MSG_ANNOUNCE_RACE = 140;
const int MSG_ANNOUNCE_ATTRIB = 141;
const int MSG_ANNOUNCE_CARD = 142;
const int MSG_ANNOUNCE_NUMBER = 143;
const int MSG_RELOAD_FIELD = 162;
const int MSG_SIBYL_NAME = 235;

// HandType enum values
const int HAND_TYPE_UNKNOWN = 0;
const int HAND_TYPE_SCISSORS = 1;
const int HAND_TYPE_ROCK = 2;
const int HAND_TYPE_PAPER = 3;

// CardZone hex values
const int CARD_ZONE_DECK = 0x01;
const int CARD_ZONE_HAND = 0x02;
const int CARD_ZONE_MZONE = 0x04;
const int CARD_ZONE_SZONE = 0x08;
const int CARD_ZONE_GRAVE = 0x10;
const int CARD_ZONE_REMOVED = 0x20;
const int CARD_ZONE_EXTRA = 0x40;
const int CARD_ZONE_ONFIELD = 0x0c;
const int CARD_ZONE_FZONE = 0x100;
const int CARD_ZONE_PZONE = 0x200;
const int CARD_ZONE_TZONE = 0x300;
const int LOCATION_OVERLAY = 0x80;

// CardPosition bitfield values
const int POS_FACEUP_ATTACK = 0x1;
const int POS_FACEDOWN_ATTACK = 0x2;
const int POS_FACEUP_DEFENSE = 0x4;
const int POS_FACEDOWN_DEFENSE = 0x8;
const int POS_FACEUP = 0x5;
const int POS_FACEDOWN = 0xa;
const int POS_ATTACK = 0x3;
const int POS_DEFENSE = 0xc;

// HsPlayerChange states
const int HS_PLAYER_STATE_MOVE = 0;
const int HS_PLAYER_STATE_READY = 1;
const int HS_PLAYER_STATE_NO_READY = 2;
const int HS_PLAYER_STATE_LEAVE = 3;
const int HS_PLAYER_STATE_TO_OBSERVER = 4;

// Error types
const int ERROR_TYPE_JOIN = 0;
const int ERROR_TYPE_DECK = 1;
const int ERROR_TYPE_SIDE = 2;
const int ERROR_TYPE_VERSION = 3;

// Self types
const int SELF_TYPE_PLAYER1 = 0;
const int SELF_TYPE_PLAYER2 = 1;
const int SELF_TYPE_OBSERVER = 7;

// Update action flags
const int UPDATE_FLAG_CODE = 0x1;
const int UPDATE_FLAG_POSITION = 0x2;
const int UPDATE_FLAG_ALIAS = 0x4;
const int UPDATE_FLAG_TYPE = 0x8;
const int UPDATE_FLAG_LEVEL = 0x10;
const int UPDATE_FLAG_RANK = 0x20;
const int UPDATE_FLAG_ATTRIBUTE = 0x40;
const int UPDATE_FLAG_RACE = 0x80;
const int UPDATE_FLAG_ATTACK = 0x100;
const int UPDATE_FLAG_DEFENSE = 0x200;
const int UPDATE_FLAG_BASE_ATTACK = 0x400;
const int UPDATE_FLAG_BASE_DEFENSE = 0x800;
const int UPDATE_FLAG_REASON = 0x1000;
const int UPDATE_FLAG_REASON_CARD = 0x2000;
const int UPDATE_FLAG_EQUIP_CARD = 0x4000;
const int UPDATE_FLAG_TARGET_CARD = 0x8000;
const int UPDATE_FLAG_OVERLAY_CARD = 0x10000;
const int UPDATE_FLAG_COUNTERS = 0x20000;
const int UPDATE_FLAG_OWNER = 0x40000;
const int UPDATE_FLAG_STATUS = 0x80000;
const int UPDATE_FLAG_LSCALE = 0x100000;
const int UPDATE_FLAG_RSCALE = 0x200000;
const int UPDATE_FLAG_LINK = 0x400000;

// Phase values
const int PHASE_DRAW = 0x01;
const int PHASE_STANDBY = 0x02;
const int PHASE_MAIN1 = 0x04;
const int PHASE_BATTLE_START = 0x08;
const int PHASE_BATTLE_STEP = 0x10;
const int PHASE_DAMAGE = 0x20;
const int PHASE_DAMAGE_CAL = 0x40;
const int PHASE_BATTLE = 0x80;
const int PHASE_MAIN2 = 0x100;
const int PHASE_END = 0x200;

// Hint commands
const int HINT_EVENT = 1;
const int HINT_MESSAGE = 2;
const int HINT_SELECTMSG = 3;
const int HINT_OPSELECTED = 4;
const int HINT_EFFECT = 5;
const int HINT_RACE = 6;
const int HINT_ATTRIB = 7;
const int HINT_CODE = 8;
const int HINT_NUMBER = 9;
const int HINT_CARD = 10;
const int HINT_ZONE = 11;
