package app.jeeb.mobile

/**
 * Dedicated launcher host for the non-production Dev Tool.
 *
 * A manifest activity-alias cannot start a second Flutter surface once the
 * single-top [MainActivity] already exists: Android only delivers a new intent
 * to the product activity, whose Dart root is already running. A real activity
 * gives the Dev Tool its own Flutter engine and task while both activities keep
 * the same application package, SharedPreferences, and secure token storage.
 */
class DevToolActivity : MainActivity() {
    override fun getInitialRoute(): String = "/devtool"
}
