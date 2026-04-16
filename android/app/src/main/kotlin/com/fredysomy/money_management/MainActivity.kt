package com.fredysomy.money_management

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.database.Cursor
import java.util.Calendar
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val batteryChannel = "com.fredysomy.money_management/battery"
    private val smsChannel = "com.fredysomy.money_management/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, batteryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        ).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTodaySms" -> {
                        try {
                            val daysBack = (call.argument<Int>("daysBack") ?: 1)
                            val cal = Calendar.getInstance()
                            cal.set(Calendar.HOUR_OF_DAY, 0)
                            cal.set(Calendar.MINUTE, 0)
                            cal.set(Calendar.SECOND, 0)
                            cal.set(Calendar.MILLISECOND, 0)
                            cal.add(Calendar.DAY_OF_YEAR, -(daysBack - 1))
                            val startOfDay = cal.timeInMillis

                            val uri = Uri.parse("content://sms/inbox")
                            val projection = arrayOf("_id", "address", "body", "date")
                            val selection = "date >= ?"
                            val selectionArgs = arrayOf(startOfDay.toString())
                            val sortOrder = "date DESC"

                            val cursor: Cursor? = contentResolver.query(
                                uri, projection, selection, selectionArgs, sortOrder
                            )

                            val smsList = mutableListOf<Map<String, Any?>>()
                            cursor?.use { c ->
                                val idIdx = c.getColumnIndexOrThrow("_id")
                                val addrIdx = c.getColumnIndexOrThrow("address")
                                val bodyIdx = c.getColumnIndexOrThrow("body")
                                val dateIdx = c.getColumnIndexOrThrow("date")
                                while (c.moveToNext()) {
                                    smsList.add(mapOf(
                                        "id" to c.getString(idIdx),
                                        "address" to (c.getString(addrIdx) ?: ""),
                                        "body" to (c.getString(bodyIdx) ?: ""),
                                        "date" to c.getLong(dateIdx)
                                    ))
                                }
                            }
                            result.success(smsList)
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", "READ_SMS permission not granted", null)
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
