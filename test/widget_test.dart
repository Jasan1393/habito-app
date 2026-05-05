import 'package:flutter_test/flutter_test.dart';
import 'package:habito/core/config/app_config.dart';
import 'package:habito/features/auth/models/auth_user.dart';
import 'package:habito/features/points/models/points_history_entry.dart';
import 'package:habito/features/points/models/points_summary.dart';
import 'package:habito/features/points/provider/points_provider.dart';
import 'package:habito/features/shop/models/shop_payment_method.dart';

void main() {
  group('AppConfig', () {
    test('expone configuración base por defecto', () {
      expect(AppConfig.apiBaseUrl, contains('/wp-json/habito/v1'));
      expect(AppConfig.wooStoreBaseUrl, contains('/wp-json/wc/store/v1'));
      expect(AppConfig.myBookingsTimeout, const Duration(seconds: 35));
    });
  });

  group('ShopPaymentMethod', () {
    test('marca métodos online como no creables manualmente', () {
      final method = ShopPaymentMethod.fromJson({
        'id': 'payphone',
        'title': 'Pago en línea',
        'requires_online_payment': true,
      });

      expect(method.requiresOnlinePayment, isTrue);
      expect(method.canCreateManualOrder, isFalse);
      expect(method.flow, 'online');
      expect(method.orderStatus, 'pending');
    });

    test('usa transferencia como respaldo manual seguro', () {
      final method = ShopPaymentMethod.fromJson({
        'id': 'bacs',
        'enabled': true,
      });

      expect(method.id, 'bacs');
      expect(method.title, ShopPaymentMethod.bankTransfer.title);
      expect(method.requiresOnlinePayment, isFalse);
      expect(method.canCreateManualOrder, isTrue);
      expect(method.orderStatus, 'on-hold');
    });
  });

  group('Puntos', () {
    test('parsea resumen e historial desde la respuesta del bridge', () {
      final summary = PointsSummary.fromJson({
        'enabled': '1',
        'mycred_available': true,
        'balance': '12.50',
        'total_earned': 25,
        'point_type': 'mycred_default',
        'label': 'Puntos',
        'next_goal': '50',
        'to_next_goal': '37.5',
        'redeem_enabled': '0',
        'booking_points_enabled': '1',
        'order_points_enabled': '1',
      });
      final entry = PointsHistoryEntry.fromJson({
        'id': '7',
        'title': 'Compra completada',
        'amount': '-2.5',
        'amount_formatted': '-2.5',
        'date_display': 'Hoy',
        'reference_id': '99',
      });

      expect(summary.enabled, isTrue);
      expect(summary.formattedBalance, '12.5');
      expect(summary.formattedToNextGoal, '37.5');
      expect(summary.bookingPointsEnabled, isTrue);
      expect(entry.id, 7);
      expect(entry.amount, -2.5);
      expect(entry.referenceId, 99);
    });

    test('sincroniza el resumen local aunque puntos este desactivado', () {
      final provider = PointsProvider();

      provider.updateSession(
        token: 'token',
        user: const AuthUser(
          id: 1,
          email: 'a@habito.test',
          firstName: 'A',
          lastName: 'Cliente',
          displayName: 'A Cliente',
          phone: '',
          birthday: '',
          address: '',
          photoUrl: '',
          pointsEnabled: true,
          pointsBalance: 20,
          pointsTotalEarned: 30,
        ),
      );
      provider.updateSession(
        token: 'token',
        user: const AuthUser(
          id: 2,
          email: 'b@habito.test',
          firstName: 'B',
          lastName: 'Cliente',
          displayName: 'B Cliente',
          phone: '',
          birthday: '',
          address: '',
          photoUrl: '',
          pointsEnabled: false,
        ),
      );

      expect(provider.summary?.enabled, isFalse);
      expect(provider.summary?.balance, 0);
      expect(provider.history, isEmpty);
    });
  });
}
