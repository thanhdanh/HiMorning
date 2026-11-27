package com.himorning.android.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.DirectionsWalk
import androidx.compose.material.icons.outlined.NotificationsActive
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.himorning.android.R
import com.himorning.android.core.MorningAccess
import com.himorning.android.core.annualSavingsPercent
import com.himorning.android.platform.BillingCatalog
import com.himorning.android.platform.BillingPlan
import com.himorning.android.platform.BillingUiState
import com.himorning.android.platform.PlayBillingManager

@Composable
internal fun ProSheet(
    billingState: BillingUiState,
    access: MorningAccess,
    previewHasStarted: Boolean,
    previewRemainingDays: Int,
    onSubscribe: (BillingPlan) -> Unit,
    onRestore: () -> Unit,
    onRetryCatalog: () -> Unit,
    onManageSubscription: () -> Unit,
) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    var selectedProductId by remember { mutableStateOf(PlayBillingManager.MONTHLY_PRODUCT_ID) }

    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text(
            stringResource(R.string.pro_headline),
            style = MaterialTheme.typography.headlineSmall,
            fontFamily = quicksandFont,
            color = colors.ink,
        )

        Column(
            Modifier.fillMaxWidth()
                .morningSurface(colors.surface, radius = 18.dp, borderColor = colors.line)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ProBenefitRow(
                icon = Icons.Outlined.NotificationsActive,
                title = stringResource(R.string.pro_benefit_challenges_title),
                description = stringResource(R.string.pro_benefit_challenges_desc),
            )
            Divider(color = colors.line)
            ProBenefitRow(
                icon = Icons.Outlined.BarChart,
                title = stringResource(R.string.pro_benefit_progress_title),
                description = stringResource(R.string.pro_benefit_progress_desc),
            )
            Divider(color = colors.line)
            ProBenefitRow(
                icon = Icons.Outlined.DirectionsWalk,
                title = stringResource(R.string.pro_benefit_journey_title),
                description = stringResource(R.string.pro_benefit_journey_desc),
            )
        }

        if (!billingState.isPro && access == MorningAccess.PREVIEW) {
            Text(
                if (previewHasStarted) stringResource(R.string.pro_preview_days_left, previewRemainingDays)
                else stringResource(R.string.pro_preview_starts_on_first_alarm),
                style = MaterialTheme.typography.bodySmall,
                color = colors.muted,
            )
        }

        if (billingState.isPro) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.CheckCircle, null, tint = colors.success, modifier = Modifier.size(20.dp))
                Text(stringResource(R.string.pro_active), style = MaterialTheme.typography.titleSmall, color = colors.success)
            }
            MorningButton(stringResource(R.string.pro_manage_subscription), onClick = onManageSubscription)
        } else {
            when (val catalog = billingState.catalog) {
                is BillingCatalog.Loading -> {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        repeat(2) {
                            Box(
                                Modifier.fillMaxWidth().height(68.dp)
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(colors.soft),
                            )
                        }
                    }
                }
                is BillingCatalog.Unavailable -> {
                    Text(stringResource(R.string.pro_plans_unavailable), style = MaterialTheme.typography.bodyMedium, color = colors.muted)
                    MorningButton(stringResource(R.string.pro_try_again), onClick = onRetryCatalog)
                }
                is BillingCatalog.Failed -> {
                    Text(stringResource(R.string.pro_plans_failed), style = MaterialTheme.typography.bodyMedium, color = colors.muted)
                    MorningButton(stringResource(R.string.pro_try_again), onClick = onRetryCatalog)
                }
                is BillingCatalog.Available -> {
                    val selectedPlan = catalog.plans.firstOrNull { it.productId == selectedProductId } ?: catalog.plans.first()
                    val monthlyPlan = catalog.plans.firstOrNull { !it.isAnnual }
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.pro_choose_plan), style = MaterialTheme.typography.titleMedium, color = colors.ink)
                        catalog.plans.forEach { plan ->
                            val savings = if (plan.isAnnual && monthlyPlan != null) {
                                annualSavingsPercent(
                                    monthlyPriceMicros = monthlyPlan.priceAmountMicros,
                                    annualPriceMicros = plan.priceAmountMicros,
                                    sameCurrency = monthlyPlan.currencyCode == plan.currencyCode,
                                )
                            } else null
                            ProPlanCard(
                                plan = plan,
                                selected = plan.productId == selectedPlan.productId,
                                savingsPercent = savings,
                                enabled = !billingState.purchasing,
                                onSelect = { selectedProductId = plan.productId },
                            )
                        }
                        Text(stringResource(R.string.pro_renews_note), style = MaterialTheme.typography.bodySmall, color = colors.muted)
                        MorningButton(
                            text = stringResource(R.string.pro_subscribe),
                            enabled = !billingState.purchasing && !billingState.restoring,
                            onClick = { onSubscribe(selectedPlan) },
                        )
                        Text(stringResource(R.string.pro_free_tier_note), style = MaterialTheme.typography.bodySmall, color = colors.muted)
                    }
                }
            }
        }

        billingState.statusMessageRes?.let { msgRes ->
            Text(stringResource(msgRes), style = MaterialTheme.typography.bodySmall, color = colors.ink)
        }

        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(
                onClick = onRestore,
                enabled = !billingState.restoring && !billingState.purchasing,
            ) {
                Text(
                    stringResource(if (billingState.restoring) R.string.pro_restoring else R.string.pro_restore),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            TextButton(onClick = {
                runCatching {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://himorning-support.onrender.com/#quyen-rieng-tu")))
                }
            }) {
                Text(stringResource(R.string.pro_privacy_policy), style = MaterialTheme.typography.bodySmall)
            }
            TextButton(onClick = {
                runCatching {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/about/play-terms/")))
                }
            }) {
                Text(stringResource(R.string.pro_terms_of_use), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun ProBenefitRow(icon: ImageVector, title: String, description: String) {
    val colors = MorningTheme.colors
    val dark = isSystemInDarkTheme()
    val badgeBg = if (dark) Color(0xFF363025) else Color(0xFFFBF4E5)
    val badgeEdge = if (dark) Color(0xFF736043) else Color(0xFFC09A50).copy(alpha = 0.45f)
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        Box(
            Modifier.size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(badgeBg)
                .border(0.75.dp, badgeEdge, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = colors.accent, modifier = Modifier.size(18.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = colors.ink)
            Text(description, style = MaterialTheme.typography.bodySmall, color = colors.muted)
        }
    }
}

@Composable
private fun ProPlanCard(
    plan: BillingPlan,
    selected: Boolean,
    savingsPercent: Int?,
    enabled: Boolean,
    onSelect: () -> Unit,
) {
    val colors = MorningTheme.colors
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier.fillMaxWidth()
            .clip(shape)
            .background(if (selected) colors.soft else colors.surface)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) colors.accent else colors.line, shape)
            .clickable(enabled = enabled, onClick = onSelect)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(if (plan.isAnnual) R.string.pro_yearly else R.string.pro_monthly),
                    style = MaterialTheme.typography.titleSmall,
                    color = colors.ink,
                )
                if (savingsPercent != null) {
                    Text(
                        stringResource(R.string.pro_save_percent, savingsPercent),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = Color(0xFF4E3516),
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(Color(0xFFFFF2CF))
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
            }
            Text(
                stringResource(if (plan.isAnnual) R.string.pro_price_per_year else R.string.pro_price_per_month, plan.formattedPrice),
                style = MaterialTheme.typography.titleMedium,
                color = colors.ink,
            )
        }
        Icon(
            if (selected) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (selected) colors.accent else colors.muted,
        )
    }
}
