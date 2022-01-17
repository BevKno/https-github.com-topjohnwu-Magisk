package com.topjohnwu.magisk.ui

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.TimeInterpolator
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.MenuItem
import android.view.View
import android.view.WindowManager
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.view.forEach
import androidx.core.view.isGone
import androidx.core.view.isVisible
import androidx.interpolator.view.animation.FastOutLinearInInterpolator
import androidx.interpolator.view.animation.LinearOutSlowInInterpolator
import androidx.navigation.NavDirections
import com.topjohnwu.magisk.MainDirections
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.BaseMainActivity
import com.topjohnwu.magisk.arch.BaseViewModel
import com.topjohnwu.magisk.arch.ReselectionTarget
import com.topjohnwu.magisk.core.*
import com.topjohnwu.magisk.databinding.ActivityMainMd2Binding
import com.topjohnwu.magisk.di.viewModel
import com.topjohnwu.magisk.ktx.startAnimations
import com.topjohnwu.magisk.ui.home.HomeFragmentDirections
import com.topjohnwu.magisk.utils.Utils
import com.topjohnwu.magisk.view.MagiskDialog
import com.topjohnwu.magisk.view.Shortcuts
import java.io.File

class MainViewModel : BaseViewModel()

class MainActivity : BaseMainActivity<MainViewModel, ActivityMainMd2Binding>() {

    override val layoutRes = R.layout.activity_main_md2
    override val viewModel by viewModel<MainViewModel>()
    override val navHostId: Int = R.id.main_nav_host
    override val snackbarAnchorView: View?
        get() {
            val fragmentAnchor = currentFragment?.snackbarAnchorView
            return when {
                fragmentAnchor?.isVisible == true -> fragmentAnchor
                binding.mainNavigation.isVisible -> return binding.mainNavigation
                else -> null
            }
        }

    private var isRootFragment = true

    override fun showMainUI(savedInstanceState: Bundle?) {
        setContentView()
        showUnsupportedMessage()
        askForHomeShortcut()

        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        navigation?.addOnDestinationChangedListener { _, destination, _ ->
            isRootFragment = when (destination.id) {
                R.id.homeFragment,
                R.id.modulesFragment,
                R.id.superuserFragment,
                R.id.logFragment -> true
                else -> false
            }

            setDisplayHomeAsUpEnabled(!isRootFragment)
            requestNavigationHidden(!isRootFragment)

            binding.mainNavigation.menu.forEach {
                if (it.itemId == destination.id) {
                    it.isChecked = true
                }
            }
        }

        setSupportActionBar(binding.mainToolbar)

        binding.mainNavigation.setOnItemSelectedListener {
            getScreen(it.itemId)?.navigate()
            true
        }
        binding.mainNavigation.setOnItemReselectedListener {
            (currentFragment as? ReselectionTarget)?.onReselected()
        }
        binding.mainNavigation.menu.apply {
            findItem(R.id.superuserFragment)?.isEnabled = Utils.showSuperUser()
            findItem(R.id.modulesFragment)?.isEnabled = Info.env.isActive
        }

        val section =
            if (intent.action == Intent.ACTION_APPLICATION_PREFERENCES)
                Const.Nav.SETTINGS
            else
                intent.getStringExtra(Const.Key.OPEN_SECTION)

        getScreen(section)?.navigate()

        if (!isRootFragment) {
            requestNavigationHidden(requiresAnimation = savedInstanceState == null)
        }
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        when (item.itemId) {
            android.R.id.home -> onBackPressed()
            else -> return super.onOptionsItemSelected(item)
        }
        return true
    }

    fun setDisplayHomeAsUpEnabled(isEnabled: Boolean) {
        binding.mainToolbar.startAnimations()
        when {
            isEnabled -> binding.mainToolbar.setNavigationIcon(R.drawable.ic_back_md2)
            else -> binding.mainToolbar.navigationIcon = null
        }
    }

    internal fun requestNavigationHidden(hide: Boolean = true, requiresAnimation: Boolean = true) {
        val bottomView = binding.mainNavigation
        if (requiresAnimation) {
            bottomView.isVisible = true
            bottomView.isHidden = hide
        } else {
            bottomView.isGone = hide
        }
    }

    fun invalidateToolbar() {
        //binding.mainToolbar.startAnimations()
        binding.mainToolbar.invalidate()
    }

    private fun getScreen(name: String?): NavDirections? {
        return when (name) {
            Const.Nav.SUPERUSER -> MainDirections.actionSuperuserFragment()
            Const.Nav.MODULES -> MainDirections.actionModuleFragment()
            Const.Nav.SETTINGS -> HomeFragmentDirections.actionHomeFragmentToSettingsFragment()
            else -> null
        }
    }

    private fun getScreen(id: Int): NavDirections? {
        return when (id) {
            R.id.homeFragment -> MainDirections.actionHomeFragment()
            R.id.modulesFragment -> MainDirections.actionModuleFragment()
            R.id.superuserFragment -> MainDirections.actionSuperuserFragment()
            R.id.logFragment -> MainDirections.actionLogFragment()
            else -> null
        }
    }

    private fun showUnsupportedMessage() {
        if (Info.env.isUnsupported) {
            MagiskDialog(this)
                .applyTitle(R.string.unsupport_magisk_title)
                .applyMessage(R.string.unsupport_magisk_msg, Const.Version.MIN_VERSION)
                .applyButton(MagiskDialog.ButtonType.POSITIVE) { titleRes = android.R.string.ok }
                .cancellable(false)
                .reveal()
        }

        if (!Info.isEmulator && Info.env.isActive && System.getenv("PATH")
                ?.split(':')
                ?.filterNot { File("$it/magisk").exists() }
                ?.any { File("$it/su").exists() } == true) {
            MagiskDialog(this)
                .applyTitle(R.string.unsupport_general_title)
                .applyMessage(R.string.unsupport_other_su_msg)
                .applyButton(MagiskDialog.ButtonType.POSITIVE) { titleRes = android.R.string.ok }
                .cancellable(false)
                .reveal()
        }

        if (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0) {
            MagiskDialog(this)
                .applyTitle(R.string.unsupport_general_title)
                .applyMessage(R.string.unsupport_system_app_msg)
                .applyButton(MagiskDialog.ButtonType.POSITIVE) { titleRes = android.R.string.ok }
                .cancellable(false)
                .reveal()
        }

        if (applicationInfo.flags and ApplicationInfo.FLAG_EXTERNAL_STORAGE != 0) {
            MagiskDialog(this)
                .applyTitle(R.string.unsupport_general_title)
                .applyMessage(R.string.unsupport_external_storage_msg)
                .applyButton(MagiskDialog.ButtonType.POSITIVE) { titleRes = android.R.string.ok }
                .cancellable(false)
                .reveal()
        }
    }

    private fun askForHomeShortcut() {
        if (isRunningAsStub && !Config.askedHome &&
            ShortcutManagerCompat.isRequestPinShortcutSupported(this)) {
            // Ask and show dialog
            Config.askedHome = true
            MagiskDialog(this)
                .applyTitle(R.string.add_shortcut_title)
                .applyMessage(R.string.add_shortcut_msg)
                .applyButton(MagiskDialog.ButtonType.NEGATIVE) {
                    titleRes = android.R.string.cancel
                }.applyButton(MagiskDialog.ButtonType.POSITIVE) {
                    titleRes = android.R.string.ok
                    onClick {
                        Shortcuts.addHomeIcon(this@MainActivity)
                    }
                }.cancellable(true)
                .reveal()
        }
    }
}
