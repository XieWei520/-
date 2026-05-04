/// Base view interface for MVP architecture
/// 
/// This interface defines the contract between View and Presenter in MVP architecture.
abstract class BaseView {
  /// Show loading indicator
  void showLoading();

  /// Hide loading indicator
  void hideLoading();

  /// Show error message
  void showError(String message);

  /// Show success message
  void showSuccess(String message);
}

/// Base view interface with no parameters
abstract class BaseViewN extends BaseView {}
