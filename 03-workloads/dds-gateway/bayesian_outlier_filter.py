#!/usr/bin/env python3
"""
03-workloads/dds-gateway/bayesian_outlier_filter.py

Bayesian outlier filter for WooliesX store edge events.

Concept: CCG Technologies bird-tracking project (2008–2014).
At the Bering Strait, RF clutter from fishing boats and military radar caused
false-positive bird pings. The Bayesian filter raised the likelihood threshold
dynamically — from p=0.70 (normal conditions) to p=0.95 (high-clutter Bering Strait)
before confirming a bird crossing.

Applied here:
  - "birds" = POS scan events from NCR terminals
  - "RF clutter" = stuck scanners, network bursts, sensor noise
  - "Bering Strait" = Saturday afternoon peak (max noise, max stakes)

A stuck scanner reporting 500% of normal scan rate in 60 seconds is a false positive.
If these events reach Kafka → GCP BigQuery, they corrupt Vertex AI demand forecasts
and drive false over-ordering. We quarantine them at the edge.

Algorithm:
  - Maintain rolling 60-second window per SKU per store
  - Compute Bayesian posterior: P(real_event | scan_rate_observed)
  - If posterior < threshold → quarantine event, fire Alertmanager alert
  - Threshold adapts: raises during peak hours (same as Bering Strait high-clutter)

Runs as: MicroShift pod, subscribes to DDS topic "pos/transaction"
Outputs clean events to: DDS topic "events/clean" → Kafka → BigQuery
"""

import json
import math
import time
import logging
import threading
from collections import defaultdict, deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, Deque

import paho.mqtt.client as mqtt   # for Alertmanager integration via MQTT
import requests                    # for Prometheus pushgateway metrics

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [bayesian-filter] %(message)s'
)
log = logging.getLogger(__name__)


@dataclass
class StoreContext:
    """Runtime context for the store — equivalent to Bering Strait weather priors."""
    store_id: str
    store_tier: str = "supermarket"   # supermarket | metro | liquor
    is_peak_hour: bool = False        # Saturday 2pm = Bering Strait
    wan_down: bool = False            # offline mode — queuing locally


@dataclass
class SKUStats:
    """Rolling statistics for one SKU in one store."""
    window_seconds: int = 60
    scan_times: Deque[float] = field(default_factory=lambda: deque(maxlen=10000))
    quarantine_count: int = 0
    pass_count: int = 0


class BayesianOutlierFilter:
    """
    Bayesian outlier filter — WooliesX POS event stream.

    Prior: P(real_event) = scan_rate_history for this SKU at this store
    Likelihood: P(observed_rate | real_event) vs P(observed_rate | stuck_scanner)
    Posterior: P(real_event | observed_rate) via Bayes theorem

    Dynamic threshold adapts to store context:
      Normal:    posterior > 0.70 → pass
      Peak hour: posterior > 0.85 → pass  (Bering Strait: raise threshold)
      WAN down:  posterior > 0.60 → pass  (more lenient — queue everything locally)
    """

    def __init__(self, store_ctx: StoreContext):
        self.ctx = store_ctx
        self.sku_stats: Dict[str, SKUStats] = defaultdict(SKUStats)
        self._lock = threading.Lock()

        # Baseline scan rates per SKU (learned from history, seeded with defaults)
        # In production: loaded from Redis/Thanos baseline per store
        self.baseline_rates: Dict[str, float] = {}
        self.default_baseline_scans_per_minute = 3.0

        log.info(
            "BayesianOutlierFilter init — store=%s tier=%s",
            store_ctx.store_id, store_ctx.store_tier
        )

    def _threshold(self) -> float:
        """Dynamic threshold — raises during peak, lowers when WAN is down."""
        if self.ctx.wan_down:
            return 0.60   # more lenient offline — queue everything, sort out later
        if self.ctx.is_peak_hour:
            return 0.85   # Saturday peak = Bering Strait: raise threshold
        return 0.70       # normal conditions

    def _scan_rate_per_minute(self, sku: str) -> float:
        """Compute current scan rate for SKU in rolling window."""
        stats = self.sku_stats[sku]
        now = time.monotonic()
        cutoff = now - stats.window_seconds
        # Prune stale events
        while stats.scan_times and stats.scan_times[0] < cutoff:
            stats.scan_times.popleft()
        elapsed = min(stats.window_seconds, now - stats.scan_times[0]) if stats.scan_times else stats.window_seconds
        return (len(stats.scan_times) / elapsed) * 60 if elapsed > 0 else 0.0

    def _posterior(self, sku: str, observed_rate: float) -> float:
        """
        P(real_event | observed_rate) using Bayesian update.

        Simplified model:
          P(real) = 0.98 prior (most events are real)
          P(observed_rate | real) ∝ Poisson(lambda=baseline, k=observed)
          P(observed_rate | stuck) ∝ Poisson(lambda=100*baseline, k=observed)
        """
        baseline = self.baseline_rates.get(sku, self.default_baseline_scans_per_minute)
        p_real = 0.98   # strong prior — most POS events are genuine

        # Poisson log-likelihood
        def log_poisson(lam: float, k: float) -> float:
            if lam <= 0 or k < 0:
                return -1e9
            return k * math.log(lam) - lam - math.lgamma(k + 1)

        ll_real  = log_poisson(baseline,        observed_rate)
        ll_stuck = log_poisson(baseline * 50.0, observed_rate)  # stuck scanner = 50x

        # Log-space Bayes: posterior ∝ likelihood * prior
        log_posterior_real  = ll_real  + math.log(p_real)
        log_posterior_stuck = ll_stuck + math.log(1 - p_real)

        # Normalise
        log_max = max(log_posterior_real, log_posterior_stuck)
        p_real_given_obs = math.exp(log_posterior_real - log_max) / (
            math.exp(log_posterior_real - log_max) +
            math.exp(log_posterior_stuck - log_max)
        )
        return p_real_given_obs

    def process_event(self, event: dict) -> dict:
        """
        Process one POS transaction event.

        Returns:
          { "action": "pass" | "quarantine", "posterior": float, "event": dict }
        """
        sku = event.get("sku", "UNKNOWN")
        store_id = event.get("store_id", self.ctx.store_id)

        with self._lock:
            stats = self.sku_stats[sku]
            stats.scan_times.append(time.monotonic())
            observed_rate = self._scan_rate_per_minute(sku)
            posterior = self._posterior(sku, observed_rate)
            threshold = self._threshold()

        action = "pass" if posterior >= threshold else "quarantine"

        if action == "quarantine":
            stats.quarantine_count += 1
            log.warning(
                "QUARANTINE sku=%s store=%s rate=%.1f/min posterior=%.3f threshold=%.2f "
                "peak=%s wan_down=%s",
                sku, store_id, observed_rate, posterior, threshold,
                self.ctx.is_peak_hour, self.ctx.wan_down
            )
            self._fire_alert(sku, store_id, observed_rate, posterior)
        else:
            stats.pass_count += 1

        return {
            "action": action,
            "posterior": round(posterior, 4),
            "observed_rate_per_min": round(observed_rate, 2),
            "threshold": threshold,
            "event": event,
        }

    def _fire_alert(self, sku: str, store_id: str, rate: float, posterior: float):
        """Push alert to Alertmanager — fire before Kafka and cloud even know."""
        alert = {
            "labels": {
                "alertname": "POSOutlierDetected",
                "severity": "warning",
                "store_id": store_id,
                "sku": sku,
                "component": "bayesian-outlier-filter",
            },
            "annotations": {
                "summary": f"Possible stuck scanner: SKU {sku} at {rate:.1f} scans/min",
                "description": (
                    f"Bayesian posterior {posterior:.3f} below threshold. "
                    f"Event quarantined — will not reach BigQuery. "
                    f"Check checkout terminal at store {store_id}."
                ),
            },
            "generatorURL": f"http://localhost:9090/alerts?store={store_id}",
        }
        try:
            requests.post(
                "http://localhost:9093/api/v1/alerts",
                json=[alert],
                timeout=2,
            )
        except Exception as exc:
            log.warning("Alertmanager push failed (non-fatal): %s", exc)

    def update_baseline(self, sku: str, baseline_scans_per_min: float):
        """Update learned baseline for a SKU (called from Thanos/Vertex AI feedback)."""
        self.baseline_rates[sku] = baseline_scans_per_min

    def update_context(self, is_peak_hour: bool = None, wan_down: bool = None):
        """Update store context — MCP agent calls this when conditions change."""
        if is_peak_hour is not None:
            self.ctx.is_peak_hour = is_peak_hour
            log.info("Context update: peak_hour=%s (threshold now %.2f)",
                     is_peak_hour, self._threshold())
        if wan_down is not None:
            self.ctx.wan_down = wan_down
            log.info("Context update: wan_down=%s (threshold now %.2f)",
                     wan_down, self._threshold())

    def stats_summary(self) -> dict:
        """Return summary for Prometheus metrics endpoint."""
        total_pass = sum(s.pass_count for s in self.sku_stats.values())
        total_quar = sum(s.quarantine_count for s in self.sku_stats.values())
        return {
            "store_id": self.ctx.store_id,
            "total_events_passed": total_pass,
            "total_events_quarantined": total_quar,
            "quarantine_rate": total_quar / max(total_pass + total_quar, 1),
            "skus_tracked": len(self.sku_stats),
            "peak_hour": self.ctx.is_peak_hour,
            "wan_down": self.ctx.wan_down,
        }


# ── Demo / test harness ───────────────────────────────────────────────────────
if __name__ == "__main__":
    ctx = StoreContext(store_id="NSW-042", store_tier="supermarket")
    f = BayesianOutlierFilter(ctx)

    # Simulate normal events
    for _ in range(10):
        r = f.process_event({"sku": "5000112637922", "store_id": "NSW-042",
                              "quantity": 1, "price": 3.50})
        print(f"Normal event: {r['action']} (posterior={r['posterior']})")

    # Simulate stuck scanner — 200 scans in 10 seconds
    for _ in range(200):
        f.sku_stats["5000112637922"].scan_times.append(time.monotonic())
    r = f.process_event({"sku": "5000112637922", "store_id": "NSW-042",
                          "quantity": 1, "price": 3.50})
    print(f"\nStuck scanner: {r['action']} (posterior={r['posterior']}, "
          f"rate={r['observed_rate_per_min']:.0f}/min)")

    # Simulate peak hour — threshold raises
    f.update_context(is_peak_hour=True)
    print(f"\nStats: {json.dumps(f.stats_summary(), indent=2)}")
