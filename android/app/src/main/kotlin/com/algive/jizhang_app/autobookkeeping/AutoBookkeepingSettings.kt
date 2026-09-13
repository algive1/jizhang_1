package com.algive.jizhang_app.autobookkeeping
import android.content.Context
object AutoBookkeepingSettings { private const val P="autobookkeeping"; fun enabled(c:Context)=c.getSharedPreferences(P,0).getBoolean("enabled",false); fun setEnabled(c:Context,v:Boolean)=c.getSharedPreferences(P,0).edit().putBoolean("enabled",v).apply() }
