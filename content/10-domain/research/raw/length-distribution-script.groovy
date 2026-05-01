/**
 * Скрипт RES-009.1 §3 — распределение длин текстовых атрибутов на стенде llm2.
 *
 * Запуск: smps run-script <этот файл> на инстансе llm2 от системного юзера
 * с правами на чтение целевых FQN. Выход — JSON в stdout (logger.info), который
 * researcher складывает в content/10-domain/research/raw/length-distribution.csv.
 *
 * Метрики на корпус: count, sum_chars, mean, p50, p90, p95, p99, max, est_tokens (chars/4).
 * Дополнительно — распределение «комментариев на заявку» (RES-009.1 §3a).
 *
 * Безопасность: PII не выводится. Логируем только агрегаты (длина, количество).
 * HQL — параметризованный, без интерполяции (NFR-043).
 */

import org.slf4j.LoggerFactory

def logger = LoggerFactory.getLogger('RES-009.1')

def percentile(List<Long> sorted, double p) {
    if (sorted.isEmpty()) return 0L
    int idx = Math.max(0, Math.min(sorted.size() - 1, (int) Math.ceil(p * sorted.size()) - 1))
    return sorted[idx]
}

def stats = { String label, List<Long> lengths ->
    def sorted = lengths.sort()
    def n = sorted.size()
    def sum = sorted.sum() ?: 0L
    return [
        label    : label,
        count    : n,
        sum_chars: sum,
        mean     : n > 0 ? (sum / n).toLong() : 0L,
        p50      : percentile(sorted, 0.50),
        p90      : percentile(sorted, 0.90),
        p95      : percentile(sorted, 0.95),
        p99      : percentile(sorted, 0.99),
        max      : sorted ? sorted[-1] : 0L,
        est_tokens_p95: ((percentile(sorted, 0.95) ?: 0L) / 4).toLong(),
        est_tokens_max: ((sorted ? sorted[-1] : 0L) / 4).toLong()
    ]
}

// ── Issue.description ─────────────────────────────────────────────────────────
def issueDescLengths = api.db.query('''
    SELECT length(coalesce(description, ''))
    FROM issue
    WHERE description IS NOT NULL AND length(description) > 0
''').list().collect { it as Long }

// ── Issue.subject ─────────────────────────────────────────────────────────────
def issueSubjLengths = api.db.query('''
    SELECT length(coalesce(subject, ''))
    FROM issue
    WHERE subject IS NOT NULL AND length(subject) > 0
''').list().collect { it as Long }

// ── IssueComment.text (или подкласс — уточнить по метамодели) ─────────────────
// FQN комментария может отличаться от 'comment' — researcher уточняет через MCP
// metamodel_export_class перед запуском скрипта.
def commentLengths = api.db.query('''
    SELECT length(coalesce(text, ''))
    FROM comment
    WHERE text IS NOT NULL AND length(text) > 0
''').list().collect { it as Long }

// ── Комментариев на заявку ────────────────────────────────────────────────────
def commentsPerIssue = api.db.query('''
    SELECT count(c)
    FROM issue i
    LEFT JOIN i.comments c
    GROUP BY i
''').list().collect { it as Long }

// ── Problem.description ───────────────────────────────────────────────────────
def problemDescLengths = api.db.query('''
    SELECT length(coalesce(description, ''))
    FROM problem
    WHERE description IS NOT NULL AND length(description) > 0
''').list().collect { it as Long }

// ── KbArticle.text ────────────────────────────────────────────────────────────
def kbTextLengths = api.db.query('''
    SELECT length(coalesce(text, ''))
    FROM knowledgeBase$article
    WHERE text IS NOT NULL AND length(text) > 0
''').list().collect { it as Long }

def report = [
    generated_at: new Date().toString(),
    stand       : 'llm2',
    note        : 'est_tokens = chars / 4 (rough). Verify with embedding API on representative sample.',
    distributions: [
        stats('issue.description',   issueDescLengths),
        stats('issue.subject',       issueSubjLengths),
        stats('comment.text',        commentLengths),
        stats('comments_per_issue',  commentsPerIssue),
        stats('problem.description', problemDescLengths),
        stats('kbArticle.text',      kbTextLengths)
    ]
]

logger.info("RES-009.1 result: ${groovy.json.JsonOutput.toJson(report)}")

// CSV для сохранения в content/10-domain/research/raw/length-distribution.csv
def csv = new StringBuilder('label,count,sum_chars,mean,p50,p90,p95,p99,max,est_tokens_p95,est_tokens_max\n')
report.distributions.each { d ->
    csv << "${d.label},${d.count},${d.sum_chars},${d.mean},${d.p50},${d.p90},${d.p95},${d.p99},${d.max},${d.est_tokens_p95},${d.est_tokens_max}\n"
}
logger.info("CSV:\n${csv}")
