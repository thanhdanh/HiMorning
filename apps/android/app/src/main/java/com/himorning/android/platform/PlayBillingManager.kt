package com.himorning.android.platform

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.annotation.StringRes
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.himorning.android.R
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

internal data class BillingPlan(
    val productId: String,
    val isAnnual: Boolean,
    val formattedPrice: String,
    val priceAmountMicros: Long,
    val currencyCode: String,
    val offerToken: String,
    internal val productDetails: ProductDetails,
)

internal sealed interface BillingCatalog {
    data object Loading : BillingCatalog
    data object Unavailable : BillingCatalog
    data object Failed : BillingCatalog
    data class Available(val plans: List<BillingPlan>) : BillingCatalog
}

internal data class BillingUiState(
    val isPro: Boolean = false,
    val catalog: BillingCatalog = BillingCatalog.Loading,
    val purchasing: Boolean = false,
    val restoring: Boolean = false,
    @StringRes val statusMessageRes: Int? = null,
)

internal class PlayBillingManager(context: Context) : PurchasesUpdatedListener {
    private val appContext = context.applicationContext
    private val _state = MutableStateFlow(BillingUiState())
    val state: StateFlow<BillingUiState> = _state.asStateFlow()

    private val client: BillingClient = BillingClient.newBuilder(appContext)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder()
                .enableOneTimeProducts()
                .build(),
        )
        .build()

    fun refresh() {
        ensureConnected {
            queryActiveSubscriptions(fromRestore = false)
            queryCatalog()
        }
    }

    fun reloadCatalog() {
        _state.update { it.copy(catalog = BillingCatalog.Loading, statusMessageRes = null) }
        ensureConnected { queryCatalog() }
    }

    fun restorePurchases() {
        if (_state.value.restoring || _state.value.purchasing) return
        _state.update { it.copy(restoring = true, statusMessageRes = null) }
        ensureConnected(onFailure = {
            _state.update { it.copy(restoring = false, statusMessageRes = R.string.pro_purchase_failed) }
        }) {
            queryActiveSubscriptions(fromRestore = true)
        }
    }

    fun launchPurchase(activity: Activity, plan: BillingPlan) {
        if (_state.value.purchasing || _state.value.restoring) return
        _state.update { it.copy(purchasing = true, statusMessageRes = null) }
        val params = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(plan.productDetails)
            .setOfferToken(plan.offerToken)
            .build()
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(params))
            .build()
        val result = client.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            _state.update { it.copy(purchasing = false, statusMessageRes = R.string.pro_purchase_failed) }
        }
    }

    fun openManageSubscriptions(context: Context) {
        val uri = Uri.parse("https://play.google.com/store/account/subscriptions?package=${appContext.packageName}")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { context.startActivity(intent) }
    }

    fun close() {
        runCatching { client.endConnection() }
    }

    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: MutableList<Purchase>?) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                handlePurchases(purchases.orEmpty(), fromRestore = false)
                _state.update { it.copy(purchasing = false) }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                _state.update { it.copy(purchasing = false) }
            }
            else -> {
                _state.update { it.copy(purchasing = false, statusMessageRes = R.string.pro_purchase_failed) }
            }
        }
    }

    private fun ensureConnected(
        onFailure: (() -> Unit)? = null,
        onConnected: () -> Unit,
    ) {
        if (client.isReady) {
            onConnected()
            return
        }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    onConnected()
                } else {
                    _state.update {
                        it.copy(
                            catalog = if (it.catalog is BillingCatalog.Loading) BillingCatalog.Failed else it.catalog,
                        )
                    }
                    onFailure?.invoke()
                }
            }

            override fun onBillingServiceDisconnected() {
                // Reconnect lazily on the next refresh/restore/purchase attempt.
            }
        })
    }

    private fun queryActiveSubscriptions(fromRestore: Boolean) {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        client.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                handlePurchases(purchases, fromRestore = fromRestore)
            } else if (fromRestore) {
                _state.update { it.copy(restoring = false, statusMessageRes = R.string.pro_purchase_failed) }
            }
        }
    }

    private fun handlePurchases(purchases: List<Purchase>, fromRestore: Boolean) {
        var hasPro = false
        var hasPending = false
        for (purchase in purchases) {
            if (!purchase.products.any { it in PRODUCT_IDS }) continue
            when (purchase.purchaseState) {
                Purchase.PurchaseState.PURCHASED -> {
                    hasPro = true
                    if (!purchase.isAcknowledged) {
                        val ack = AcknowledgePurchaseParams.newBuilder()
                            .setPurchaseToken(purchase.purchaseToken)
                            .build()
                        client.acknowledgePurchase(ack) { }
                    }
                }
                Purchase.PurchaseState.PENDING -> hasPending = true
            }
        }
        _state.update { current ->
            val msg = when {
                fromRestore -> if (hasPro) R.string.pro_restored else R.string.pro_no_active_subscription
                hasPending -> R.string.pro_purchase_pending
                hasPro -> null
                else -> current.statusMessageRes
            }
            current.copy(isPro = hasPro, restoring = false, statusMessageRes = msg)
        }
    }

    private fun queryCatalog() {
        val productList = PRODUCT_IDS.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()
        client.queryProductDetailsAsync(params) { result, queryResult ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                _state.update { it.copy(catalog = BillingCatalog.Failed) }
                return@queryProductDetailsAsync
            }
            val detailsList = queryResult.productDetailsList
            val plans = PRODUCT_IDS.mapNotNull { id ->
                val details = detailsList.firstOrNull { it.productId == id } ?: return@mapNotNull null
                val offer = details.subscriptionOfferDetails?.firstOrNull() ?: return@mapNotNull null
                val phase = offer.pricingPhases.pricingPhaseList.firstOrNull() ?: return@mapNotNull null
                BillingPlan(
                    productId = id,
                    isAnnual = id == ANNUAL_PRODUCT_ID,
                    formattedPrice = phase.formattedPrice,
                    priceAmountMicros = phase.priceAmountMicros,
                    currencyCode = phase.priceCurrencyCode,
                    offerToken = offer.offerToken,
                    productDetails = details,
                )
            }
            _state.update {
                it.copy(catalog = if (plans.isNotEmpty()) BillingCatalog.Available(plans) else BillingCatalog.Unavailable)
            }
        }
    }

    companion object {
        const val MONTHLY_PRODUCT_ID = "com.himorning.pro.monthly"
        const val ANNUAL_PRODUCT_ID = "com.himorning.pro.annual"
        val PRODUCT_IDS = listOf(MONTHLY_PRODUCT_ID, ANNUAL_PRODUCT_ID)
    }
}
