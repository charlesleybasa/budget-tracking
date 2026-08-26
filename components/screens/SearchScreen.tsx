"use client";

import { useDeferredValue, useMemo, useState } from "react";

import { Mascot } from "@/components/Mascot";
import { ReceiptViewer } from "@/components/ReceiptViewer";
import { SpriteAnimation } from "@/components/SpriteAnimation";
import { TxRow } from "@/components/TxRow";
import { SEARCH_FILTERS } from "@/lib/constants";
import { dayLabel, peso0 } from "@/lib/format";
import { findCard, searchTransactions } from "@/lib/selectors";
import { IDLE_STEADY } from "@/lib/sprites";
import { useWallet } from "@/lib/store";
import type { SearchFilter, Transaction } from "@/lib/types";

import styles from "./SearchScreen.module.css";

export function SearchScreen() {
  const { state, actions } = useWallet();
  const [receipt, setReceipt] = useState<Transaction | null>(null);
  const deferredQuery = useDeferredValue(state.query);
  const results = useMemo(
    () => searchTransactions(state.tx, deferredQuery, state.filter),
    [state.tx, deferredQuery, state.filter],
  );
  const hasSearch = state.query.trim().length > 0;
  const hasFilters = hasSearch || state.filter !== "All";
  const isRecent = !hasFilters;

  const { moneyOut, moneyIn, groups } = useMemo(() => {
    let moneyOutTotal = 0;
    let moneyInTotal = 0;
    const resultGroups: Array<{ key: string; label: string; rows: Transaction[] }> = [];

    for (const transaction of results) {
      if (transaction.amount < 0) moneyOutTotal += Math.abs(transaction.amount);
      else moneyInTotal += transaction.amount;

      const key = new Date(transaction.at).toDateString();
      const current = resultGroups.at(-1);
      if (current?.key === key) current.rows.push(transaction);
      else resultGroups.push({ key, label: dayLabel(transaction.at), rows: [transaction] });
    }

    return { moneyOut: moneyOutTotal, moneyIn: moneyInTotal, groups: resultGroups };
  }, [results]);

  const resetSearch = () => actions.patch({ query: "", filter: "All" });

  return (
    <section
      className={`${styles.screen} bwEnterUp`}
      aria-label="Search history"
    >
      <div className={styles.header}>
        <div className={styles.headerInner}>
          <div className={styles.heading}>
            <div className={styles.eyebrow}>Activity</div>
            <h1 className={styles.title}>Find a transaction</h1>
            <p className={styles.subtitle}>Search by merchant, note, or category.</p>
          </div>

          <div className={styles.searchField}>
            <svg className={styles.searchIcon} width={19} height={19} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" aria-hidden="true">
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
            {hasSearch ? (
              <button
                type="button"
                className={styles.clearQuery}
                onClick={() => actions.patch({ query: "" })}
                aria-label="Clear search"
              >
                <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.3} strokeLinecap="round" aria-hidden="true">
                  <path d="M7 7l10 10M17 7 7 17" />
                </svg>
              </button>
            ) : null}
          </div>

          <div className={styles.filterRail}>
            <div className={styles.filters} role="group" aria-label="Filter transactions">
              {SEARCH_FILTERS.map((filter) => {
                const active = state.filter === filter;
                return (
                  <button
                    key={filter}
                    type="button"
                    className={`${styles.filter} ${active ? styles.filterActive : ""}`}
                    onClick={() => actions.patch({ filter: filter as SearchFilter })}
                    aria-pressed={active}
                  >
                    {filter}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      <div className={styles.scroll}>
        <div className={styles.scrollInner}>
          <div className={styles.resultsHeading}>
            <div>
              <h2 className={styles.resultsTitle}>{isRecent ? "Recent activity" : "Search results"}</h2>
              <div className={styles.count} aria-live="polite">
                {results.length} {results.length === 1 ? "transaction" : "transactions"}
              </div>
            </div>
            {hasFilters ? (
              <button type="button" className={styles.reset} onClick={resetSearch}>
                Reset
              </button>
            ) : null}
          </div>

          {results.length > 0 ? (
            <div className={styles.overview} aria-label="Search totals">
              <div className={styles.totalCard}>
                <span className={`${styles.totalIcon} ${styles.outIcon}`} aria-hidden="true">↓</span>
                <span className={styles.totalCopy}>
                  <span className={styles.totalLabel}>Money out</span>
                  <strong className={styles.totalValue}>₱{peso0(moneyOut)}</strong>
                </span>
              </div>
              <div className={`${styles.totalCard} ${styles.inCard}`}>
                <span className={`${styles.totalIcon} ${styles.inIcon}`} aria-hidden="true">↑</span>
                <span className={styles.totalCopy}>
                  <span className={styles.totalLabel}>Money in</span>
                  <strong className={`${styles.totalValue} ${styles.inValue}`}>₱{peso0(moneyIn)}</strong>
                </span>
              </div>
            </div>
          ) : null}

          {groups.map((group) => (
            <section key={group.key} className={styles.group} aria-label={group.label}>
              <div className={styles.groupLabel}>{group.label}</div>
              <div className={styles.resultList}>
                {group.rows.map((transaction, index) => (
                  <TxRow
                    key={transaction.id}
                    tx={transaction}
                    cardNick={findCard(state.cards, transaction.cardId)?.nick ?? "Deleted card"}
                    variant="search"
                    index={index}
                    onClick={() => actions.openTxEdit(transaction.id)}
                    onViewReceipt={setReceipt}
                  />
                ))}
              </div>
            </section>
          ))}

          {results.length === 0 ? (
            <div className={`${styles.empty} ${state.tx.length === 0 ? styles.emptyWithMascot : ""}`}>
              {state.tx.length === 0 ? (
                <SpriteAnimation
                  sheet={IDLE_STEADY}
                  size={96}
                  className={styles.emptyMascot}
                  fallback={<Mascot mood="idle" size={96} className={styles.emptyMascotFallback} />}
                />
              ) : (
                <div className={styles.emptyIcon} aria-hidden="true">
                  <svg width={26} height={26} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
                    <circle cx={10.5} cy={10.5} r={6.5} />
                    <path d="M15.5 15.5 20 20" />
                  </svg>
                </div>
              )}
              <div className={styles.emptyTitle}>
                {state.tx.length === 0
                  ? "Your activity will show up here"
                  : hasSearch
                    ? `No matches for “${state.query.trim()}”`
                    : "No transactions in this filter"}
              </div>
              <div className={styles.emptyBody}>
                {state.tx.length === 0
                  ? "Log your first spend or top up to start building your history."
                  : "Try another word or reset the filters to see everything again."}
              </div>
              <button
                type="button"
                className={styles.emptyAction}
                onClick={state.tx.length === 0 ? () => actions.openSheet("withdraw") : resetSearch}
              >
                {state.tx.length === 0 ? "Log a spend" : "Show all activity"}
              </button>
            </div>
          ) : null}
        </div>
      </div>

      {receipt?.receipt ? (
        <ReceiptViewer src={receipt.receipt} merchant={receipt.merchant} onClose={() => setReceipt(null)} />
      ) : null}
    </section>
  );
}
