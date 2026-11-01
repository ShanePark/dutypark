package com.tistory.shanepark.dutypark.push.config

import nl.martijndwars.webpush.Encoding
import nl.martijndwars.webpush.Notification
import nl.martijndwars.webpush.PushService
import org.apache.http.client.config.RequestConfig
import org.apache.http.client.methods.HttpPost

class NonRedirectingPushService(publicKey: String, privateKey: String, subject: String) :
    PushService(publicKey, privateKey, subject) {
    override fun preparePost(notification: Notification, encoding: Encoding): HttpPost =
        super.preparePost(notification, encoding).apply {
            config = RequestConfig.custom().setRedirectsEnabled(false).build()
        }
}
