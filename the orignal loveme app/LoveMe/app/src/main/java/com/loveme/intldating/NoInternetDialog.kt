package com.loveme.intldating

import android.app.Dialog
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.Window
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast

class NoInternetDialog(context: Context) : Dialog(context) {

    private lateinit var imageView: ImageView
    private lateinit var titleText: TextView
    private lateinit var messageText: TextView
    private lateinit var checkButton: Button
    private lateinit var closeButton: ImageButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setContentView(R.layout.dialog_no_internet)

        window?.setBackgroundDrawable(ColorDrawable(Color.WHITE))
        window?.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT
        )
        window?.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)

        setCancelable(false)
        setCanceledOnTouchOutside(false)

        imageView = findViewById(R.id.noInternetImage)
        titleText = findViewById(R.id.noInternetTitle)
        messageText = findViewById(R.id.noInternetMessage)
        checkButton = findViewById(R.id.checkInternetButton)
        closeButton = findViewById(R.id.closeButton)

        try {
            val inputStream = context.assets.open("no imter image.png")
            val bitmap = BitmapFactory.decodeStream(inputStream)
            imageView.setImageBitmap(bitmap)
            inputStream.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        titleText.text = "You seem to be offline"
        messageText.text = "Looks like love took a pause… Check your internet connection ❤️"

        closeButton.setOnClickListener {
            dismiss()
        }

        checkButton.setOnClickListener {
            if (NetworkUtil.isInternetAvailable(context)) {
                dismiss()
            } else {
                Toast.makeText(context, "Still no internet connection", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
