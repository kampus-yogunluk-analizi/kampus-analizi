import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('shows campus density dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusDensityApp(enableRealtime: false));

    expect(find.text('Kampus Yogunluk Analizi'), findsOneWidget);
    expect(find.text('Toplam cihaz'), findsOneWidget);
    expect(find.text('Kutuphane'), findsWidgets);
    expect(find.text('Kafeterya'), findsWidgets);
  });
}
