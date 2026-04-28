-- ============================================================
-- PLM Analytics Queries: Recipe Development System
-- ООО «ПепсиКо Холдингс»
-- Author: P. Chervotkin | NUST MISiS
-- ============================================================

USE plm_db;

-- ---------------------------------------------------------------
-- Q1. Полный состав утверждённых рецептур
--     Метод соединения: неявный JOIN через WHERE
-- ---------------------------------------------------------------
SELECT
    r.recipe_id,
    r.recipe_code,
    r.recipe_name,
    r.recipe_status,
    dp.development_date,
    ri.step_number,
    ri.quantity,
    ri.recipe_unit,
    ri.is_critical,
    i.ingredient_id,
    i.ingredient_code,
    i.ingredient_name,
    ic.category_name   AS ingredient_category,
    i.unit_of_measure  AS ingredient_unit,
    i.cost_per_unit
FROM recipes            r,
     recipe_ingredients ri,
     ingredients        i,
     ingredient_categories ic,
     development_projects  dp
WHERE ri.recipe_id     = r.recipe_id
  AND ri.ingredient_id = i.ingredient_id
  AND i.category_id    = ic.category_id
  AND r.project_id     = dp.project_id
  AND r.recipe_status  = 'Утверждён'
ORDER BY r.recipe_code ASC, ri.step_number ASC;


-- ---------------------------------------------------------------
-- Q2. То же самое через INNER JOIN — рекомендуемый стиль
-- ---------------------------------------------------------------
SELECT
    r.recipe_id,
    r.recipe_code,
    r.recipe_name,
    r.recipe_status,
    dp.development_date,
    ri.step_number,
    ri.quantity,
    ri.recipe_unit,
    ri.is_critical,
    i.ingredient_id,
    i.ingredient_code,
    i.ingredient_name,
    ic.category_name   AS ingredient_category,
    i.unit_of_measure  AS ingredient_unit,
    i.cost_per_unit
FROM recipes r
INNER JOIN development_projects  dp ON dp.project_id     = r.project_id
INNER JOIN recipe_ingredients    ri ON ri.recipe_id      = r.recipe_id
INNER JOIN ingredients            i ON  i.ingredient_id  = ri.ingredient_id
INNER JOIN ingredient_categories ic ON ic.category_id    = i.category_id
WHERE r.recipe_status = 'Утверждён'
ORDER BY r.recipe_code ASC, ri.step_number ASC;


-- ---------------------------------------------------------------
-- Q3. Классификация статусов рецептур через CASE
--     Читаемые описания этапов для отчётности руководству
-- ---------------------------------------------------------------
SELECT
    r.recipe_id,
    r.recipe_code,
    r.recipe_name,
    r.recipe_status                          AS original_status,
    dp.development_date,
    dp.project_name,
    e.full_name                              AS created_by_name,
    CASE r.recipe_status
        WHEN 'Черновик'        THEN 'Находится в разработке'
        WHEN 'На согласовании' THEN 'Проходит лабораторные испытания'
        WHEN 'Утверждён'       THEN 'Готов к передаче в производство'
        WHEN 'Архив'           THEN 'Требует доработки после испытаний'
        ELSE 'Статус не определён'
    END                                      AS status_description,
    CASE r.recipe_status
        WHEN 'Черновик'        THEN 'Высший приоритет'
        WHEN 'На согласовании' THEN 'Средний приоритет'
        WHEN 'Утверждён'       THEN 'Начальная стадия разработки'
        ELSE 'Низкий приоритет'
    END                                      AS processing_priority
FROM recipes r
INNER JOIN development_projects dp ON dp.project_id = r.project_id
LEFT  JOIN employees             e ON  e.employee_id = r.created_by
ORDER BY r.recipe_id;


-- ---------------------------------------------------------------
-- Q4. Аналитика по проектам: число версий рецептур
--     GROUP BY + HAVING — выводим только проекты с > 2 рецептурами
--     Индикатор сложности разработки для руководства R&D
-- ---------------------------------------------------------------
SELECT
    dp.project_id,
    dp.project_code,
    dp.project_name,
    dp.project_status,
    dp.priority,
    dp.start_date,
    dp.deadline_date,
    e.full_name                                                             AS main_technologist,
    COUNT(r.recipe_id)                                                      AS total_recipes,
    COUNT(DISTINCT r.version)                                               AS unique_versions,
    SUM(CASE WHEN r.recipe_status = 'Утверждён'       THEN 1 ELSE 0 END)   AS approved_recipes,
    SUM(CASE WHEN r.recipe_status = 'На согласовании' THEN 1 ELSE 0 END)   AS testing_recipes,
    SUM(CASE WHEN r.recipe_status = 'Черновик'        THEN 1 ELSE 0 END)   AS draft_recipes,
    MIN(r.development_date)                                                 AS first_recipe_date,
    MAX(r.development_date)                                                 AS last_recipe_date,
    GROUP_CONCAT(DISTINCT r.recipe_code ORDER BY r.recipe_code SEPARATOR ', ') AS all_recipe_codes
FROM development_projects dp
LEFT JOIN recipes   r ON r.project_id  = dp.project_id
LEFT JOIN employees e ON e.employee_id = dp.main_technologist
GROUP BY
    dp.project_id, dp.project_code, dp.project_name,
    dp.project_status, dp.priority, dp.start_date,
    dp.deadline_date, e.full_name
HAVING COUNT(r.recipe_id) > 2
ORDER BY total_recipes DESC;


-- ---------------------------------------------------------------
-- Q5. Неиспользуемые ингредиенты — вложенный подзапрос NOT IN
--     Задача для отдела снабжения: оптимизация складских запасов
-- ---------------------------------------------------------------
SELECT
    i.ingredient_id,
    i.ingredient_code,
    i.ingredient_name,
    ic.category_name,
    i.supplier,
    i.cost_per_unit,
    i.unit_of_measure  AS unit,
    i.shelf_life_days,
    i.is_active,
    i.created_at,
    i.allergens_list,
    i.selection_reason,
    -- Сколько ингредиентов в той же категории уже используется
    (
        SELECT COUNT(DISTINCT ri2.ingredient_id)
        FROM recipe_ingredients ri2
        INNER JOIN ingredients  i2 ON i2.ingredient_id = ri2.ingredient_id
        WHERE i2.category_id = i.category_id
    ) AS recipes_using_this_category
FROM ingredients i
LEFT JOIN ingredient_categories ic ON ic.category_id = i.category_id
WHERE i.is_active = 1
  AND i.ingredient_id NOT IN (
      SELECT DISTINCT ri.ingredient_id
      FROM recipe_ingredients ri
  )
ORDER BY ic.category_name, i.ingredient_name;


-- ---------------------------------------------------------------
-- Q6. Сводный отчёт по себестоимости рецептур
--     Автоматический флаг превышения лимита из технического задания
-- ---------------------------------------------------------------
SELECT
    r.recipe_code,
    r.recipe_name,
    r.recipe_status,
    dp.project_name,
    ROUND(SUM(ri.quantity * i.cost_per_unit), 2)     AS estimated_cost_rub,
    ta.target_cost_rub,
    ROUND(
        (SUM(ri.quantity * i.cost_per_unit) - ta.target_cost_rub)
        / ta.target_cost_rub * 100,
    2)                                               AS cost_deviation_pct,
    CASE
        WHEN SUM(ri.quantity * i.cost_per_unit) > ta.target_cost_rub
            THEN '⚠ ПРЕВЫШЕНИЕ ЛИМИТА — уведомить бренд-менеджера'
        ELSE '✓ В рамках бюджета'
    END                                              AS budget_flag
FROM recipes r
INNER JOIN recipe_ingredients   ri ON ri.recipe_id   = r.recipe_id
INNER JOIN ingredients           i ON  i.ingredient_id = ri.ingredient_id
INNER JOIN development_projects dp ON dp.project_id  = r.project_id
LEFT  JOIN technical_assignments ta ON ta.project_id = dp.project_id
GROUP BY
    r.recipe_id, r.recipe_code, r.recipe_name,
    r.recipe_status, dp.project_name, ta.target_cost_rub
ORDER BY cost_deviation_pct DESC;
