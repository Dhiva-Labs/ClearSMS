package com.dhivalabs.clear_sms

/**
 * On-device rule-based classifier in the spirit of Microsoft SMS Organizer.
 * Categories: personal, otp, transaction, promotion.
 * Everything runs locally; nothing ever leaves the phone.
 */
object SmsClassifier {

    const val CATEGORY_PERSONAL = "personal"
    const val CATEGORY_OTP = "otp"
    const val CATEGORY_TRANSACTION = "transaction"
    const val CATEGORY_PROMOTION = "promotion"

    // OTP: a 4-8 digit code near verification wording. Every alternative ends
    // in a word character so the trailing \b works ("code:" would not).
    private val otpKeywords = Regex(
        "\\b(otp|one[- ]?time|verification|verify|auth(entication)? code|" +
            "security code|login code|passcode|access code|code|" +
            "(code|pin) is|is your (code|pin)|" +
            "do not share|don'?t share)\\b",
        RegexOption.IGNORE_CASE
    )
    private val otpCode = Regex("\\b(\\d{4,8})\\b")
    private val otpCodeHyphen = Regex("\\b(\\d{3}[- ]\\d{3})\\b")

    private val transactionKeywords = Regex(
        "\\b(debited|credited|withdrawn|deposited|a/c|acct|account|txn|transaction|" +
            "balance|bal|upi|neft|imps|rtgs|autopay|e-?mandate|emi|payment|paid|" +
            "purchase of|spent|received|transferred|refund(ed)?|invoice|bill|" +
            "statement|card ending|min(imum)? due|credit card|debit card)\\b",
        RegexOption.IGNORE_CASE
    )
    private val currencyPattern = Regex(
        "(₹|\\brs\\.?\\s?\\d|\\binr\\b|\\$\\d|\\busd\\b|\\beur\\b)",
        RegexOption.IGNORE_CASE
    )

    private val promoKeywords = Regex(
        "\\b(sale|% off|percent off|discount|offer|deal|cashback|coupon|promo|" +
            "flat \\d+|buy 1|buy one|free delivery|limited time|hurry|shop now|" +
            "order now|subscribe|unsubscribe|t&c|tnc apply|exclusive|mega|" +
            "bumper|lucky draw|win|congratulations you|click here|link below|" +
            "download now|install now|recharge now|best price|lowest price)\\b",
        RegexOption.IGNORE_CASE
    )

    // Alphanumeric sender IDs (e.g. "VM-HDFCBK", "AX-AMAZON") are businesses,
    // never people. A sender that parses as a phone number is likely a person.
    private val phoneNumberSender = Regex("^\\+?\\d{7,15}$")
    private val shortCodeSender = Regex("^\\d{3,6}$")

    fun classify(sender: String, body: String): String {
        val cleanSender = sender.replace(Regex("[\\s()-]"), "")
        val isPersonNumber = phoneNumberSender.matches(cleanSender)
        val isShortCode = shortCodeSender.matches(cleanSender)
        val isBusinessSender = !isPersonNumber

        if (extractOtp(body) != null) return CATEGORY_OTP

        val looksTransactional =
            transactionKeywords.containsMatchIn(body) && currencyPattern.containsMatchIn(body)
        val looksPromo = promoKeywords.containsMatchIn(body)

        return when {
            looksTransactional && !looksPromo -> CATEGORY_TRANSACTION
            looksPromo && isBusinessSender -> CATEGORY_PROMOTION
            looksTransactional -> CATEGORY_TRANSACTION
            isBusinessSender || isShortCode ->
                // Business sender with no promo/txn signal: informational.
                // Treat govt/service alerts as transaction-tab material, promos otherwise.
                if (looksPromo) CATEGORY_PROMOTION else CATEGORY_TRANSACTION
            else -> CATEGORY_PERSONAL
        }
    }

    /** Returns the OTP code if the message is an OTP, else null. */
    fun extractOtp(body: String): String? {
        if (!otpKeywords.containsMatchIn(body)) return null
        otpCodeHyphen.find(body)?.let { return it.value.replace(Regex("[- ]"), "") }
        // Prefer the digit-run closest to the keyword; fall back to the first one.
        return otpCode.find(body)?.groupValues?.get(1)
    }
}
