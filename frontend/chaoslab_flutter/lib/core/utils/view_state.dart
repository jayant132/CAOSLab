/// Generic load-state used by every ViewModel in the app so Views can
/// render loading/error/success consistently without each ViewModel
/// re-inventing its own status enum.
enum ViewState { idle, loading, success, error }
