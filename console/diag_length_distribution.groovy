/**
 * Diagnostic: распределение длин текстовых атрибутов и количества комментариев
 *             на корпусе SMP-стенда (RES-009.1 §3 / §3a).
 *
 * Запуск:
 *   smps execute -f console/diag_length_distribution.groovy
 *
 * Вывод: через logger.info с префиксом [res-009.1]; smps execute стримит лог
 * в stdout. Researcher парсит итоговые JSON и CSV-блоки и складывает CSV в
 * content/10-domain/research/raw/length-distribution.csv.
 *
 * Метрики per-атрибут: count, sum_chars, mean, p50, p90, p95, p99, max,
 * est_tokens_p95/max (по коэффициенту char/token = 3.5), pct_over_2048_tok,
 * pct_under_100_tok, pct_empty_or_short. Дополнительно — комментариев на
 * parent (issue, problem) и счётчики дубликатов (issue.duplicates) для
 * оценки ground truth UC3.
 *
 * Безопасность: PII не выводится. Логируем только агрегаты (длина, количество).
 * HQL — параметризованный, без интерполяции (NFR-043).
 *
 * v2 (RES-009.1):
 * - Коэффициент char/token = 3.5 (smoke 2026-05-01: 49 символов = 14 токенов)
 * - Авто-детект имени атрибута KB (content vs text)
 * - Count дубликатов issue.duplicates для оценки ground truth UC3
 * - comment FQN — универсальный, фильтрация по c.source.metaClass
 */

import org.slf4j.LoggerFactory

def logger = LoggerFactory.getLogger('res-009.1')

def percentile(List<Long> sorted, double p) {
    if (sorted.isEmpty()) return 0L
    int idx = Math.max(0, Math.min(sorted.size() - 1, (int) Math.ceil(p * sorted.size()) - 1))
    return sorted[idx]
}

def stats = { String label, List<Long> lengths ->
    def sorted = lengths.sort()
    def n = sorted.size()
    def sum = sorted.sum() ?: 0L
    // Коэффициент 3.5 символа/токен (верифицировано на smoke 2026-05-01: 49 chars = 14 tokens)
    def TOKEN_COEFF = 3.5
    return [
        label              : label,
        count              : n,
        sum_chars          : sum,
        mean               : n > 0 ? (sum / n).toLong() : 0L,
        p50                : percentile(sorted, 0.50),
        p90                : percentile(sorted, 0.90),
        p95                : percentile(sorted, 0.95),
        p99                : percentile(sorted, 0.99),
        max                : sorted ? sorted[-1] : 0L,
        est_tokens_p95     : sorted ? ((percentile(sorted, 0.95) ?: 0L) / TOKEN_COEFF).toLong() : 0L,
        est_tokens_max     : sorted ? ((sorted[-1] ?: 0L) / TOKEN_COEFF).toLong() : 0L,
        pct_over_2048_tok  : n > 0 ? (sorted.count { it / TOKEN_COEFF > 2048 } * 100.0 / n).round(1) : 0.0,
        pct_under_100_tok  : n > 0 ? (sorted.count { it / TOKEN_COEFF < 100 } * 100.0 / n).round(1) : 0.0,
        pct_empty_or_short : n > 0 ? (sorted.count { it < 10 } * 100.0 / n).round(1) : 0.0
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

// ── Issue.decisionReport ──────────────────────────────────────────────────────
def issueDecisionLengths = api.db.query('''
    SELECT length(coalesce(decisionReport, ''))
    FROM issue
    WHERE decisionReport IS NOT NULL AND length(decisionReport) > 0
''').list().collect { it as Long }

// ── comment.text — универсальный FQN комментария ──────────────────────────────
// На llm2 'comment' — общий класс для комментариев ко всем источникам (issue,
// problem, etc.); ссылка на источник лежит в атрибуте source.
// Распределение длины комментария по всем источникам (агрегат)
def commentLengthsAll = api.db.query('''
    SELECT length(coalesce(text, ''))
    FROM comment
    WHERE text IS NOT NULL AND length(text) > 0
''').list().collect { it as Long }

// Распределение длины комментариев — только для source типа issue
def commentLengthsIssue = api.db.query('''
    SELECT length(coalesce(c.text, ''))
    FROM comment c
    WHERE c.text IS NOT NULL AND length(c.text) > 0
      AND c.source.metaClass LIKE :issuePrefix
''', [issuePrefix: 'issue%']).list().collect { it as Long }

// Распределение длины комментариев — только для source типа problem
def commentLengthsProblem = api.db.query('''
    SELECT length(coalesce(c.text, ''))
    FROM comment c
    WHERE c.text IS NOT NULL AND length(c.text) > 0
      AND c.source.metaClass LIKE :problemPrefix
''', [problemPrefix: 'problem%']).list().collect { it as Long }

// ── Комментариев на заявку (через source) ─────────────────────────────────────
def commentsPerIssue = api.db.query('''
    SELECT count(c)
    FROM issue i, comment c
    WHERE c.source = i
    GROUP BY i
''').list().collect { it as Long }

// ── Комментариев на problem ───────────────────────────────────────────────────
def commentsPerProblem = api.db.query('''
    SELECT count(c)
    FROM problem p, comment c
    WHERE c.source = p
    GROUP BY p
''').list().collect { it as Long }

// ── Problem.description ───────────────────────────────────────────────────────
def problemDescLengths = api.db.query('''
    SELECT length(coalesce(description, ''))
    FROM problem
    WHERE description IS NOT NULL AND length(description) > 0
''').list().collect { it as Long }

// ── Problem.workaround + rootCause ────────────────────────────────────────────
def problemWorkaroundLengths = api.db.query('''
    SELECT length(coalesce(workaround, ''))
    FROM problem
    WHERE workaround IS NOT NULL AND length(workaround) > 0
''').list().collect { it as Long }

def problemRootCauseLengths = api.db.query('''
    SELECT length(coalesce(rootCause, ''))
    FROM problem
    WHERE rootCause IS NOT NULL AND length(rootCause) > 0
''').list().collect { it as Long }

// ── KbArticle.content или .text — автодетект имени атрибута ──────────────────
// smp-metamodel.md называет атрибут 'content' (richtext), но в некоторых
// конфигурациях SMP он может называться 'text'. Пробуем оба варианта.
def kbContentLengths = []
def kbAttrName = 'unknown'

try {
    def contentResult = api.db.query('''
        SELECT length(coalesce(content, ''))
        FROM knowledgeBase$article
        WHERE content IS NOT NULL AND length(content) > 0
    ''').list().collect { it as Long }
    if (contentResult.size() > 0) {
        kbContentLengths = contentResult
        kbAttrName = 'content'
    }
} catch (Exception e) {
    logger.warn("RES-009.1: knowledgeBase\$article.content not found, trying .text: ${e.message}")
}

if (kbContentLengths.isEmpty()) {
    try {
        def textResult = api.db.query('''
            SELECT length(coalesce(text, ''))
            FROM knowledgeBase$article
            WHERE text IS NOT NULL AND length(text) > 0
        ''').list().collect { it as Long }
        if (textResult.size() > 0) {
            kbContentLengths = textResult
            kbAttrName = 'text'
        }
    } catch (Exception e) {
        logger.warn("RES-009.1: knowledgeBase\$article.text also not found: ${e.message}")
    }
}

logger.info("RES-009.1: KB article attr name detected: ${kbAttrName}, count=${kbContentLengths.size()}")

// ── Сводный count объектов и дубликатов (для §3a ground truth оценки) ─────────
def totalIssueCount = api.db.query('SELECT count(i) FROM issue i').list()[0] as Long
def issueWithDuplicates = api.db.query('''
    SELECT count(DISTINCT i)
    FROM issue i
    WHERE SIZE(i.duplicates) > 0 OR SIZE(i.duplicatesRL) > 0
''').list()[0] as Long

def totalProblemCount = api.db.query('SELECT count(p) FROM problem p').list()[0] as Long
def totalKbArticleCount = api.db.query('SELECT count(k) FROM knowledgeBase$article k').list()[0] as Long

// ── Composite-текст для issue (PoC whitelist: subject + cancelReason) ──────────
// Объединяем длины subject + cancelReason для оценки composite
def issueCompositePoC = api.db.query('''
    SELECT length(coalesce(subject, '')) + length(coalesce(cancelReason, ''))
    FROM issue
    WHERE subject IS NOT NULL AND length(subject) > 0
''').list().collect { it as Long }

// ── Composite для issue расширенный (+ decisionReport + feedback) ──────────────
def issueCompositeExtended = api.db.query('''
    SELECT length(coalesce(subject, ''))
         + length(coalesce(cancelReason, ''))
         + length(coalesce(decisionReport, ''))
         + length(coalesce(feedback, ''))
    FROM issue
    WHERE subject IS NOT NULL AND length(subject) > 0
''').list().collect { it as Long }

def report = [
    generated_at      : new Date().toString(),
    stand             : 'llm2',
    note              : 'est_tokens = chars / 3.5 (smoke calibration 2026-05-01: 49 chars = 14 tokens). Verify with 5 embedding API calls.',
    kb_attr_name      : kbAttrName,
    totals            : [
        issue_total         : totalIssueCount,
        issue_with_duplicates: issueWithDuplicates,
        issue_dup_pct       : totalIssueCount > 0 ? (issueWithDuplicates * 100.0 / totalIssueCount).round(1) : 0.0,
        problem_total       : totalProblemCount,
        kb_article_total    : totalKbArticleCount
    ],
    distributions: [
        stats('issue.description',                 issueDescLengths),
        stats('issue.subject',                     issueSubjLengths),
        stats('issue.decisionReport',              issueDecisionLengths),
        stats("issue.composite_poc",               issueCompositePoC),
        stats("issue.composite_extended",          issueCompositeExtended),
        stats('comment.text:all',                  commentLengthsAll),
        stats('comment.text:issue',                commentLengthsIssue),
        stats('comment.text:problem',              commentLengthsProblem),
        stats('comments_per_issue',                commentsPerIssue),
        stats('comments_per_problem',              commentsPerProblem),
        stats('problem.description',               problemDescLengths),
        stats('problem.workaround',                problemWorkaroundLengths),
        stats('problem.rootCause',                 problemRootCauseLengths),
        stats("kbArticle.${kbAttrName}",           kbContentLengths)
    ]
]

logger.info("RES-009.1 result: ${groovy.json.JsonOutput.toJson(report)}")

// CSV для сохранения в content/10-domain/research/raw/length-distribution.csv
def csv = new StringBuilder('label,count,sum_chars,mean,p50,p90,p95,p99,max,est_tokens_p95,est_tokens_max,pct_over_2048_tok,pct_under_100_tok,pct_empty_or_short\n')
report.distributions.each { d ->
    csv << "${d.label},${d.count},${d.sum_chars},${d.mean},${d.p50},${d.p90},${d.p95},${d.p99},${d.max},${d.est_tokens_p95},${d.est_tokens_max},${d.pct_over_2048_tok},${d.pct_under_100_tok},${d.pct_empty_or_short}\n"
}
logger.info("CSV:\n${csv}")
logger.info("TOTALS: ${groovy.json.JsonOutput.toJson(report.totals)}")
logger.info("KB_ATTR: ${kbAttrName}")
