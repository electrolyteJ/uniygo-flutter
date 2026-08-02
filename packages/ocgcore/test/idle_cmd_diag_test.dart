import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocgcore/ocgcore.dart';

ffi.DynamicLibrary loadOcgCore() {
  if (Platform.isMacOS) {
    try {
      return ffi.DynamicLibrary.open('macos/Frameworks/libocgcore.dylib');
    } catch (_) {}
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

CardData card(int code, int type, int level, int attr, int race, int atk,
        int def, String name) =>
    CardData(
        code: code,
        alias: 0,
        setcode: [],
        type: type,
        level: level,
        attribute: attr,
        race: race,
        attack: atk,
        defense: def,
        lscale: 0,
        rscale: 0,
        linkMarker: 0,
        ruleCode: 0,
        name: name,
        desc: '');

void main() {
  late OcgCore engine;
  setUp(() async {
    engine = (await createOcgCore(loadOcgCore()))!;
  });

  test('dump SELECT_IDLECMD sections for mixed hand', () async {
    const elf = 15025844;
    const pot = 55144522;
    const trap = 4206964;
    const celtic = 91152256;
    const baby = 88819587;

    final cards = <int, CardData>{
      elf: card(elf, TYPE_MONSTER | TYPE_NORMAL, 4, ATTRIBUTE_LIGHT, RACE_SPELLCASTER, 800, 2000, 'Elf'),
      pot: card(pot, TYPE_SPELL, 0, 0, 0, 0, 0, 'Pot of Greed'),
      trap: card(trap, TYPE_TRAP, 0, 0, 0, 0, 0, 'Trap Hole'),
      celtic: card(celtic, TYPE_MONSTER | TYPE_NORMAL, 4, ATTRIBUTE_EARTH, RACE_WARRIOR, 1400, 1200, 'Celtic'),
      baby: card(baby, TYPE_MONSTER | TYPE_NORMAL, 4, ATTRIBUTE_WIND, RACE_DRAGON, 1200, 700, 'Baby'),
    };
    engine.setCardReader((code) async => cards[code]);

    final pduel = engine.createDuel(42);
    engine.setPlayerInfo(pduel, 0, 8000, 5, 1);
    engine.setPlayerInfo(pduel, 1, 8000, 5, 1);

    // noShuffleDeck: top 5 cards = hand
    final deck = [elf, pot, trap, celtic, baby,
        elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf,
        elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf, elf,
        elf, elf, elf, elf, elf, elf, elf, elf, elf, elf];
    for (var i = 0; i < deck.length; i++) {
      engine.newCard(pduel, deck[i], 0, 0, LOCATION_DECK, i, 0);
      engine.newCard(pduel, deck[i], 1, 1, LOCATION_DECK, i, 0);
    }

    for (final s in ['constant.lua', 'utility.lua', 'procedure.lua', 'event.lua']) {
      engine.preloadScript(pduel, s);
    }

    engine.startDuel(pduel, DUEL_SIMPLE_AI);

    final buf = Uint8List(SIZE_MESSAGE_BUFFER);
    String hex(Uint8List b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

    for (var tick = 0; tick < 200; tick++) {
      final result = engine.process(pduel);
      final status = result & PROCESSOR_FLAG;
      final msgLen = result & PROCESSOR_BUFFER_LEN;
      if (msgLen > 0) {
        final data = Uint8List(msgLen);
        engine.getMessage(pduel, data);
        final func = data[0];
        if (func == MSG_SELECT_IDLECMD && data[1] == 0) {
          print('IDLE player0 len=$msgLen');
          print('IDLE raw: ${hex(data)}');
          final r = ByteData.sublistView(data);
          var off = 2;
          const sectionNames = [
            'summon', 'spsummon', 'reposition', 'mset', 'sset', 'activate',
          ];
          for (var s = 0; s < sectionNames.length; s++) {
            final count = r.getUint8(off++);
            final codes = <int>[];
            final optBytes = <String>[];
            for (var i = 0; i < count; i++) {
              codes.add(r.getUint32(off, Endian.little));
              final opt = hex(Uint8List.sublistView(data, off, off + 3));
              optBytes.add('[$opt]');
              off += s == 5 ? 8 : 7;
            }
            print('  section[$s] ${sectionNames[s]}: count=$count codes=$codes $optBytes');
          }
          final trailing = hex(Uint8List.sublistView(data, off));
          print('  trailing: $trailing');
          break;
        } else if (func == MSG_DRAW || func == MSG_NEW_TURN || func == MSG_NEW_PHASE) {
          print('MSG $func len=$msgLen: ${hex(data)}');
        }
      }
      if (status == PROCESSOR_END) break;
    }

    engine.endDuel(pduel);
  });
}
