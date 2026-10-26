import 'move_model.dart';

/// One competitor of a match.
class PlayerInfo {
  final String name;
  final bool isWhite;
  final bool isAi;
  final Difficulty? difficulty;

  const PlayerInfo({
    required this.name,
    required this.isWhite,
    required this.isAi,
    this.difficulty,
  });

  PlayerInfo copyWith({String? name, Difficulty? difficulty}) => PlayerInfo(
        name: name ?? this.name,
        isWhite: isWhite,
        isAi: isAi,
        difficulty: difficulty ?? this.difficulty,
      );
}

/// Factory helpers keeping names consistent across screens.
class PlayerFactory {
  static PlayerInfo human(bool isWhite) =>
      PlayerInfo(name: isWhite ? 'White' : 'Black', isWhite: isWhite, isAi: false);

  static PlayerInfo ai(bool isWhite, Difficulty difficulty) => PlayerInfo(
        name: 'Computer',
        isWhite: isWhite,
        isAi: true,
        difficulty: difficulty,
      );

  static PlayerInfo south(PlayerInfo top, PlayerInfo bottom, bool whiteBottom) =>
      whiteBottom ? bottom : top;
}
