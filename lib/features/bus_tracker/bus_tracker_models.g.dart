// GENERATED — manual adapter (no build_runner needed)
part of 'bus_tracker_models.dart';

class TimetableEntryAdapter extends TypeAdapter<TimetableEntry> {
  @override
  final int typeId = 10;

  @override
  TimetableEntry read(BinaryReader reader) {
    return TimetableEntry(
      routeName: reader.read() as String,
      origin: reader.read() as String,
      departureTime: reader.read() as String,
      isFromCampus: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TimetableEntry obj) {
    writer.write(obj.routeName);
    writer.write(obj.origin);
    writer.write(obj.departureTime);
    writer.write(obj.isFromCampus);
  }
}
