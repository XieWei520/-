import 'base_view.dart';

class BasePresenter<V extends BaseView> {
  V? view;

  /// Attach view to presenter
  void attachView(V v) {
    view = v;
  }

  /// Detach view from presenter
  void detachView() {
    view = null;
  }

  /// Check if view is attached
  bool get isViewAttached => view != null;

  /// Get view with null safety
  V? getmView() => view;
}

/// Base presenter with no view type
class BasePresenterN extends BasePresenter<BaseViewN> {}
