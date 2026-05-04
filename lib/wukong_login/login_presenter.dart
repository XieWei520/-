import 'login_contract.dart';
import 'login_model.dart';

/// Login presenter
class LoginPresenter extends LoginPresenterContract {
  final LoginModel _model;
  bool _isLoading = false;
  String _zoneCode = '0086'; // 默认区号

  LoginPresenter() : _model = LoginModel();

  /// 设置区号
  void setZoneCode(String zoneCode) {
    _zoneCode = zoneCode;
  }

  @override
  void detachView() {
    _model.dispose();
    super.detachView();
  }

  @override
  Future<void> login(String username, String password) async {
    if (_isLoading) return;
    _isLoading = true;
    view?.showLoading();

    try {
      // 使用手机号登录，传递区号
      final result = await _model.login(username, password, zoneCode: _zoneCode);
      
      if (result.success && result.userInfo != null) {
        view?.loginSuccess(result.userInfo!);
      } else {
        // Check if needs additional verification
        if (result.code == 1001) {
          view?.loginFail(result.code, '', username);
        } else {
          view?.showError(result.msg);
        }
      }
    } catch (e) {
      view?.showError(e.toString());
    } finally {
      _isLoading = false;
      view?.hideLoading();
    }
  }

  @override
  Future<void> sendCode(String phone, String zone, int type) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final result = await _model.sendCode(phone, zone, type);
      view?.sendCodeResult(result.code, result.msg);
    } catch (e) {
      view?.showError(e.toString());
    } finally {
      _isLoading = false;
    }
  }

  @override
  Future<void> register(
    String username,
    String password,
    String code,
    String zone,
  ) async {
    if (_isLoading) return;
    _isLoading = true;
    view?.showLoading();

    try {
      final result = await _model.register(username, password, code, zone);
      
      if (result.success && result.userInfo != null) {
        view?.loginSuccess(result.userInfo!);
      } else {
        view?.showError(result.msg);
      }
    } catch (e) {
      view?.showError(e.toString());
    } finally {
      _isLoading = false;
      view?.hideLoading();
    }
  }

  @override
  Future<void> resetPassword(
    String phone,
    String newPassword,
    String code,
    String zone,
  ) async {
    if (_isLoading) return;
    _isLoading = true;
    view?.showLoading();

    try {
      final result = await _model.resetPassword(phone, newPassword, code, zone);
      view?.resetPwdResult(result.code, result.msg);
    } catch (e) {
      view?.showError(e.toString());
    } finally {
      _isLoading = false;
      view?.hideLoading();
    }
  }

  @override
  Future<void> getCountryCodes() async {
    try {
      final codes = await _model.getCountryCodes();
      view?.setCountryCode(codes);
    } catch (e) {
      view?.showError(e.toString());
    }
  }
}
