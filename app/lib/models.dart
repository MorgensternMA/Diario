// Data classes shared by the store and the screens.

class Category {
  final int id;
  final String name;
  final String color;
  final String icon;

  const Category({this.id = 0, required this.name, required this.color, required this.icon});
}

class Event {
  final int id;
  final int? categoryId;
  final String title;
  final String date;
  final String time;
  final String notes;
  final bool done;

  const Event({
    this.id = 0,
    this.categoryId,
    required this.title,
    required this.date,
    this.time = '',
    this.notes = '',
    this.done = false,
  });

  Event copyWith({bool? done}) => Event(
    id: id,
    categoryId: categoryId,
    title: title,
    date: date,
    time: time,
    notes: notes,
    done: done ?? this.done,
  );
}

class TodoList {
  final int id;
  final String name;
  final String kind; // todo, groceries, purchases, custom
  final String icon;
  final String color;
  final int position;
  final int pending;
  final int total;

  const TodoList({
    this.id = 0,
    required this.name,
    this.kind = 'custom',
    this.icon = 'list',
    this.color = '#26A69A',
    this.position = 0,
    this.pending = 0,
    this.total = 0,
  });

  bool get hasQuantity => kind == 'groceries' || kind == 'purchases';
}

class Item {
  final int id;
  final int listId;
  final String text;
  final bool done;
  final String quantity;
  final String note;
  final String dueDate;
  final int position;

  const Item({
    this.id = 0,
    this.listId = 0,
    required this.text,
    this.done = false,
    this.quantity = '',
    this.note = '',
    this.dueDate = '',
    this.position = 0,
  });

  Item copyWith({bool? done}) => Item(
    id: id,
    listId: listId,
    text: text,
    done: done ?? this.done,
    quantity: quantity,
    note: note,
    dueDate: dueDate,
    position: position,
  );
}

class JournalEntry {
  final String date;
  final int mood; // 0 = unset, 1..5
  final List<String> feelings;
  final String note;

  const JournalEntry({required this.date, this.mood = 0, this.feelings = const [], this.note = ''});
}

class PeriodDay {
  final String date;
  final int flow; // 1 spotting .. 4 heavy
  final List<String> symptoms;
  final String note;

  const PeriodDay({required this.date, required this.flow, this.symptoms = const [], this.note = ''});
}

class Tracker {
  final int id;
  final String name;
  final String kind; // check, count, number, scale
  final String unit;
  final double goal;
  final String color;
  final String icon;
  final bool archived;
  final int position;

  const Tracker({
    this.id = 0,
    required this.name,
    this.kind = 'check',
    this.unit = '',
    this.goal = 0,
    this.color = '#42A5F5',
    this.icon = 'check',
    this.archived = false,
    this.position = 0,
  });

  /// Whether a day's value counts as "done" for streaks and the history grid.
  bool isDone(double? v) {
    if (v == null) return false;
    if (goal > 0 && (kind == 'count' || kind == 'number')) return v >= goal;
    return v > 0;
  }
}

class TrackerDay {
  final Tracker tracker;
  final double? value;
  const TrackerDay(this.tracker, this.value);
}

class TrackerEntry {
  final int trackerId;
  final String date;
  final double value;
  const TrackerEntry(this.trackerId, this.date, this.value);
}

class Day {
  final String date;
  final JournalEntry? journal;
  final PeriodDay? period;
  final List<Event> events;
  final List<TrackerDay> trackers;
  final List<Item> dueItems;

  const Day({
    required this.date,
    this.journal,
    this.period,
    this.events = const [],
    this.trackers = const [],
    this.dueItems = const [],
  });
}

class CalendarEvent {
  final int id;
  final String title;
  final String color;
  final bool done;
  const CalendarEvent(this.id, this.title, this.color, this.done);
}

class CalendarDay {
  final String date;
  final List<CalendarEvent> events;
  final int mood;
  final int flow;
  final bool predictedPeriod;
  final bool fertile;
  final bool ovulation;
  final int dueItems;

  const CalendarDay({
    required this.date,
    this.events = const [],
    this.mood = 0,
    this.flow = 0,
    this.predictedPeriod = false,
    this.fertile = false,
    this.ovulation = false,
    this.dueItems = 0,
  });
}

class Cycle {
  final String start;
  final String end;
  final int periodLength;
  final int cycleLength;
  const Cycle(this.start, this.end, this.periodLength, this.cycleLength);
}

class Prediction {
  final String start;
  final String end;
  final String ovulation;
  final String fertileStart;
  final String fertileEnd;
  const Prediction(this.start, this.end, this.ovulation, this.fertileStart, this.fertileEnd);
}

class CycleSummary {
  final bool hasData;
  final int avgCycle;
  final int avgPeriod;
  final String lastStart;
  final int cycleDay;
  final String nextStart;
  final int daysUntilNext;
  final bool inPeriod;
  final List<Cycle> cycles;
  final List<Prediction> predictions;

  const CycleSummary({
    required this.hasData,
    required this.avgCycle,
    required this.avgPeriod,
    required this.lastStart,
    required this.cycleDay,
    required this.nextStart,
    required this.daysUntilNext,
    required this.inPeriod,
    required this.cycles,
    required this.predictions,
  });
}
