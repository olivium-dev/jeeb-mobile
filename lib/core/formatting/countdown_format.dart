library;

class CountdownFormat {
  const CountdownFormat._();

  static String format(Duration d) {
    if (d.isNegative) return '0:00';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final ss = _pad(seconds);
    if (hours == 0) return '$minutes:$ss';
    return '$hours:${_pad(minutes)}:$ss';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
