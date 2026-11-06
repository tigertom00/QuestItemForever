# QuestItemForever

Adds a "Quest Item" section to item tooltips showing which quests an item belongs to, built for **World of Warcraft: Forever** (interface `16001`). It reads from the QuestieDB database, so it also works for quests that aren't in your log.

## Features

- Shows quests that need the item as an objective, need it to complete, provide it, or are started by it.
- Marks quests as `(in log)` or `(done)`.
- Colors quest names by difficulty.
- Leaves out quests your race can't do.

## Requirements

[QuestieDB](https://github.com/Questie/QuestieDB) must be installed.

## Installation

Drop the `QuestItemForever` folder into:

```
World of Warcraft/_forever_/Interface/AddOns/
```

Then `/reload` or relaunch the client.

## License

MIT — see [LICENSE](LICENSE).
