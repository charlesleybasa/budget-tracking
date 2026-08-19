"use client";

import { TxRow } from "@/components/TxRow";
import { SEARCH_FILTERS } from "@/lib/constants";
import { peso0 } from "@/lib/format";
import { findCard, searchTransactions } from "@/lib/selectors";
import { useWallet } from "@/lib/store";
import type { SearchFilter } from "@/lib/types";

import styles from "./SearchScreen.module.css";

export function SearchScreen() {
  const { state, actions } = useWallet();
  const results = searchTransactions(state.tx, state.query, state.filter);
  const total = results.reduce((sum, t) => sum + Math.abs(t.amount), 0);

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Search history"
    >
      <div className={styles.header}>
        <div className={styles.headerInner}>
        <div className={styles.searchRow}>
          <div className={styles.searchField}>
            <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,.55)" strokeWidth={2.4} strokeLinecap="round">
              <circle cx={11} cy={11} r={7} />
              <path d="M16.5 16.5L21 21" />
            </svg>
            <input
              className={styles.searchInput}
              value={state.query}
              onChange={(e) => actions.patch({ query: e.target.value })}
              placeholder="Jollibee, load, last Tuesday…"
              aria-label="Search transactions"
              type="search"
            />
          </div>
          <button type="button" className={styles.done} onClick={() => actions.go("home")}>
            Done
          </button>
        </div>

        <div className={styles.filters}>
          {SEARCH_FILTERS.map((f) => {
            const active = state.filter === f;
            return (
              <button
                key={f}
                type="button"
                className={styles.filter}
                onClick={() => actions.patch({ filter: f as SearchFilter })}
                aria-pressed={active}
                style={{
                  background: active ? "#ffca28" : "rgba(255,255,255,.1)",
                  color: active ? "#0b0b0c" : "rgba(255,255,255,.82)",
                }}
              >
                {f}
              </button>
            );
          })}
        </div>
        </div>
      </div>

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
        <div className={styles.summary}>
          <div className={styles.count}>
            {results.length} {results.length === 1 ? "match" : "matches"}
          </div>
          <div className={styles.total}>₱{peso0(total)}</div>
        </div>

        {results.map((t, i) => (
          <TxRow
            key={t.id}
            tx={t}
            cardNick={findCard(state.cards, t.cardId)?.nick ?? "Deleted card"}
            variant="search"
            index={i}
            onClick={() => {
              actions.patch({ activeId: t.cardId });
              actions.go("detail");
            }}
          />
        ))}

        {results.length === 0 ? (
          <div className={styles.empty}>
            <div className={styles.emptyTitle}>Nothing here.</div>
            <div className={styles.emptyBody}>
              Either you didn&apos;t buy it, or you didn&apos;t log it. One of those is fixable.
            </div>
          </div>
        ) : null}
        </div>
      </div>
    </section>
  );
}
