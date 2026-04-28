-- ============================================================
-- PLM Database Schema: Recipe Development Management System
-- ООО «ПепсиКо Холдингс»
-- Author: P. Chervotkin | NUST MISiS
-- DBMS: MySQL 8.0
-- ============================================================

CREATE DATABASE IF NOT EXISTS plm_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE plm_db;

-- ------------------------------------------------------------
-- Сотрудники
-- ------------------------------------------------------------
CREATE TABLE employees (
    employee_id    INT          PRIMARY KEY AUTO_INCREMENT,
    full_name      VARCHAR(100) NOT NULL,
    position       VARCHAR(100) NOT NULL,
    department     VARCHAR(100) NOT NULL,
    email          VARCHAR(150) UNIQUE,
    phone          VARCHAR(20),
    hire_date      DATE,
    is_active      BOOLEAN      DEFAULT TRUE
);

-- ------------------------------------------------------------
-- Категории ингредиентов (справочник)
-- ------------------------------------------------------------
CREATE TABLE ingredient_categories (
    category_id   INT         PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL,
    description   TEXT
);

-- ------------------------------------------------------------
-- Ингредиенты — главный справочник НСИ
-- ------------------------------------------------------------
CREATE TABLE ingredients (
    ingredient_id    INT          PRIMARY KEY AUTO_INCREMENT,
    ingredient_code  VARCHAR(20)  UNIQUE NOT NULL,
    ingredient_name  VARCHAR(200) NOT NULL,
    category_id      INT,
    supplier         VARCHAR(200),
    cost_per_unit    DECIMAL(10,2),
    unit_of_measure  VARCHAR(20)  NOT NULL,
    shelf_life_days  INT,
    is_active        BOOLEAN      DEFAULT TRUE,
    created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
    allergens_list   TEXT,
    selection_reason TEXT,
    FOREIGN KEY (category_id) REFERENCES ingredient_categories(category_id)
);

-- ------------------------------------------------------------
-- Проекты разработки
-- ------------------------------------------------------------
CREATE TABLE development_projects (
    project_id        INT          PRIMARY KEY AUTO_INCREMENT,
    project_code      VARCHAR(20)  UNIQUE NOT NULL,
    project_name      VARCHAR(200) NOT NULL,
    project_status    ENUM('В работе','Утверждён','Завершён','Отменён') NOT NULL,
    priority          ENUM('Высокий','Средний','Низкий') DEFAULT 'Средний',
    start_date        DATE,
    deadline_date     DATE,
    main_technologist INT,
    FOREIGN KEY (main_technologist) REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- Рецептуры
-- ------------------------------------------------------------
CREATE TABLE recipes (
    recipe_id       INT         PRIMARY KEY AUTO_INCREMENT,
    recipe_code     VARCHAR(30) UNIQUE NOT NULL,
    recipe_name     VARCHAR(200) NOT NULL,
    recipe_status   ENUM('Черновик','На согласовании','Утверждён','Архив') DEFAULT 'Черновик',
    project_id      INT         NOT NULL,
    development_date DATE,
    approved_by     INT,
    created_by      INT,
    version         VARCHAR(10) DEFAULT '1.0',
    FOREIGN KEY (project_id)  REFERENCES development_projects(project_id),
    FOREIGN KEY (approved_by) REFERENCES employees(employee_id),
    FOREIGN KEY (created_by)  REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- Состав рецептур (связующая таблица)
-- ------------------------------------------------------------
CREATE TABLE recipe_ingredients (
    ri_id           INT            PRIMARY KEY AUTO_INCREMENT,
    recipe_id       INT            NOT NULL,
    ingredient_id   INT            NOT NULL,
    quantity        DECIMAL(10,4)  NOT NULL,
    recipe_unit     VARCHAR(20)    NOT NULL,
    step_number     INT,
    is_critical     BOOLEAN        DEFAULT FALSE,
    FOREIGN KEY (recipe_id)     REFERENCES recipes(recipe_id),
    FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id),
    UNIQUE KEY uq_recipe_ingredient_step (recipe_id, ingredient_id, step_number)
);

-- ------------------------------------------------------------
-- Пищевая ценность (КБЖУ)
-- ------------------------------------------------------------
CREATE TABLE nutritional_values (
    nv_id          INT            PRIMARY KEY AUTO_INCREMENT,
    recipe_id      INT            UNIQUE NOT NULL,
    calories_kcal  DECIMAL(8,2),
    proteins_g     DECIMAL(8,3),
    fats_g         DECIMAL(8,3),
    carbs_g        DECIMAL(8,3),
    sodium_mg      DECIMAL(8,3),
    fiber_g        DECIMAL(8,3),
    calculated_at  DATETIME       DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (recipe_id) REFERENCES recipes(recipe_id)
);

-- ------------------------------------------------------------
-- Физико-химические показатели (ФХП)
-- ------------------------------------------------------------
CREATE TABLE recipe_physical_indicators (
    rpi_id          INT           PRIMARY KEY AUTO_INCREMENT,
    recipe_id       INT           UNIQUE NOT NULL,
    acidity_ph      DECIMAL(4,2),
    moisture_pct    DECIMAL(5,2),
    viscosity_cps   DECIMAL(8,2),
    dry_matter_pct  DECIMAL(5,2),
    shelf_life_days INT,
    test_date       DATE,
    FOREIGN KEY (recipe_id) REFERENCES recipes(recipe_id)
);

-- ------------------------------------------------------------
-- Нормативные документы
-- ------------------------------------------------------------
CREATE TABLE regulatory_documents (
    regulation_id   INT          PRIMARY KEY AUTO_INCREMENT,
    document_code   VARCHAR(50)  NOT NULL,
    document_name   VARCHAR(300) NOT NULL,
    effective_date  DATE,
    description     TEXT
);

-- ------------------------------------------------------------
-- Нормативное соответствие рецептур
-- ------------------------------------------------------------
CREATE TABLE regulatory_compliance (
    rc_id                  INT  PRIMARY KEY AUTO_INCREMENT,
    recipe_id              INT  NOT NULL,
    regulation_document_id INT,
    compliance_status      ENUM('Соответствует','Не соответствует','На проверке'),
    checked_by             INT,
    check_date             DATE,
    comments               TEXT,
    FOREIGN KEY (recipe_id)              REFERENCES recipes(recipe_id),
    FOREIGN KEY (regulation_document_id) REFERENCES regulatory_documents(regulation_id),
    FOREIGN KEY (checked_by)             REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- Аллергены (справочник)
-- ------------------------------------------------------------
CREATE TABLE allergens (
    allergen_id   INT         PRIMARY KEY AUTO_INCREMENT,
    allergen_name VARCHAR(100) NOT NULL,
    eu_code       VARCHAR(10),
    description   TEXT
);

-- ------------------------------------------------------------
-- Аллергены ингредиентов (связующая таблица)
-- ------------------------------------------------------------
CREATE TABLE ingredient_allergens (
    ia_id         INT PRIMARY KEY AUTO_INCREMENT,
    ingredient_id INT NOT NULL,
    allergen_id   INT NOT NULL,
    FOREIGN KEY (ingredient_id) REFERENCES ingredients(ingredient_id),
    FOREIGN KEY (allergen_id)   REFERENCES allergens(allergen_id),
    UNIQUE KEY uq_ingredient_allergen (ingredient_id, allergen_id)
);

-- ------------------------------------------------------------
-- Технические задания
-- ------------------------------------------------------------
CREATE TABLE technical_assignments (
    ta_id           INT          PRIMARY KEY AUTO_INCREMENT,
    project_id      INT          NOT NULL,
    ta_number       VARCHAR(30)  UNIQUE,
    requirements    TEXT,
    target_cost_rub DECIMAL(12,2),
    created_date    DATE,
    FOREIGN KEY (project_id) REFERENCES development_projects(project_id)
);

-- ------------------------------------------------------------
-- Этапы разработки
-- ------------------------------------------------------------
CREATE TABLE development_stages (
    stage_id    INT          PRIMARY KEY AUTO_INCREMENT,
    project_id  INT          NOT NULL,
    stage_name  VARCHAR(150) NOT NULL,
    start_date  DATE,
    end_date    DATE,
    status      ENUM('Не начат','В работе','Завершён') DEFAULT 'Не начат',
    responsible INT,
    FOREIGN KEY (project_id)  REFERENCES development_projects(project_id),
    FOREIGN KEY (responsible) REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- Затраты на разработку
-- ------------------------------------------------------------
CREATE TABLE development_costs (
    cost_id     INT           PRIMARY KEY AUTO_INCREMENT,
    project_id  INT           NOT NULL,
    cost_type   VARCHAR(100),
    amount_rub  DECIMAL(12,2),
    cost_date   DATE,
    description TEXT,
    FOREIGN KEY (project_id) REFERENCES development_projects(project_id)
);

-- ------------------------------------------------------------
-- Документы проекта
-- ------------------------------------------------------------
CREATE TABLE project_documents (
    doc_id        INT          PRIMARY KEY AUTO_INCREMENT,
    project_id    INT          NOT NULL,
    document_name VARCHAR(200) NOT NULL,
    document_type VARCHAR(100),
    file_path     VARCHAR(500),
    created_date  DATE,
    created_by    INT,
    FOREIGN KEY (project_id) REFERENCES development_projects(project_id),
    FOREIGN KEY (created_by) REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- Результаты испытаний
-- ------------------------------------------------------------
CREATE TABLE testing_results (
    test_id    INT          PRIMARY KEY AUTO_INCREMENT,
    recipe_id  INT          NOT NULL,
    test_type  VARCHAR(100),
    test_date  DATE,
    result     TEXT,
    passed     BOOLEAN,
    tested_by  INT,
    FOREIGN KEY (recipe_id)  REFERENCES recipes(recipe_id),
    FOREIGN KEY (tested_by)  REFERENCES employees(employee_id)
);
