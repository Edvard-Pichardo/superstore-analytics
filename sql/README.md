<div align="center">

# SuperStore Analytics — SQL / MySQL

Proyecto integral de análisis de datos con el conjunto Superstore. Incluye limpieza de datos, diseño de bases de datos relacionales, automatización con SQL (procedimientos, triggers y auditoría) y análisis con Python.

![MySQL](https://img.shields.io/badge/MySQL-8.0%2B-blue?style=for-the-badge)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)

</div>

## Descripción

Esta sección documenta la capa SQL del proyecto **SuperStore Analytics**, cuyo objetivo es transformar un dataset comercial en una estructura de datos confiable, analizable y reutilizable.

La implementación se realizó sobre **MySQL 8** y se diseñó siguiendo una separación clara entre:

- datos de origen y carga;
- limpieza y validación;
- modelo relacional;
- vistas analíticas;
- consultas de análisis;
- procedimientos almacenados;
- triggers y auditoría.

La intención no fue únicamente obtener algunas consultas de ventas, sino construir una pequeña plataforma analítica SQL reproducible.

---

## Objetivos de la capa SQL

La capa SQL persigue cinco objetivos principales:

1. **Conservar y entender el dato original.**
2. **Normalizar y validar la información antes del análisis.**
3. **Construir un modelo relacional que separe entidades y relaciones.**
4. **Centralizar la lógica analítica en vistas y consultas reutilizables.**
5. **Añadir parametrización y trazabilidad mediante procedimientos y auditoría.**

Esto permite pasar de:

```text
Dataset crudo
    ↓
Datos validados y normalizados
    ↓
Modelo relacional
    ↓
Capa analítica
    ↓
Procedimientos reutilizables
    ↓
Auditoría de cambios
```

---

## Fuente y características del dataset

El archivo de origen utilizado durante el proyecto fue:

```text
data/raw/sales_superstore_raw.csv
```

El dataset contiene **10,703 filas originales** y campos relacionados con pedidos, clientes, productos, geografía, ventas, cantidades, descuentos, beneficios y logística.

Entre las columnas principales se encuentran:

```text
Row ID
Order ID
Order Date
Ship Date
Ship Mode
Customer ID
Customer Name
Segment
Country/Region
City
State/Province
Postal Code
Region
Product ID
Category
Sub-Category
Product Name
Sales
Quantity
Discount
Profit
```

El análisis del periodo observado va de **2023-01-03 a 2026-12-30**.

---

## Estructura del repositorio SQL

La capa SQL se organiza por responsabilidades:

```text
sql/
├── ddl/
├── dml/
├── dmq/
├── analysis/
├── procedures/
└── triggers/
```

### `ddl/`

Contiene la definición de la estructura de la base: tablas, claves, restricciones e infraestructura auxiliar.

### `dml/`

Contiene la carga y/o transformación de registros.

### `dmq/`

Contiene las vistas que abstraen el modelo relacional y exponen datasets analíticos reutilizables.

### `analysis/`

Contiene las consultas exploratorias y de análisis de negocio.

### `procedures/`

Contiene procedimientos almacenados parametrizados para reutilizar análisis frecuentes.

### `triggers/`

Contiene los triggers de auditoría y las pruebas integrales del sistema de auditoría.

---

## Modelo relacional

Una de las decisiones centrales del proyecto fue pasar de una tabla plana a un **modelo relacional**, separando entidades y relaciones para evitar duplicación innecesaria y facilitar la integridad referencial.

La estructura conceptual gira alrededor de dos tablas transaccionales:

- `orders`: cabecera del pedido.
- `order_details`: líneas del pedido.

Y varias entidades de referencia, entre ellas clientes, ubicaciones, productos, categorías y modalidades de envío.


<p align="center">
  <img src="images/relational_model.png" width="600">
  <br>
  <em>Figura: Modelo relacional del dataset. Fuente: MySQL Workbench.</em>
</p>


---

## Filosofía de limpieza y calidad de datos

La limpieza no se realizó eliminando datos de forma indiscriminada. La regla general fue:

> **Solo transformar o recuperar un valor cuando existe una regla defendible. Si la evidencia no es suficiente, conservar `NULL`.**

Esto es especialmente importante para métricas comerciales como `Sales`, `Quantity` y `Profit`, porque rellenar valores arbitrariamente puede alterar las conclusiones del análisis.

### Ejemplos de normalización realizados

#### Segment

Se normalizaron variantes y errores tipográficos de la columna `segments` hasta quedarse con los tres segmentos de la empresa:

<p align="center">
  <img src="images/sql/01_validacion_segment1.png">
  <img src="images/sql/01_normalizacion_segment.png">
  <br>
  <em>Figura: Registros de la columna Segment antes y después de su normalización.</em>
</p>

#### Category

Se corrigieron diferencias de formato relacionadas a espacios en blanco hasta terminar con las tres categorías de la empresa:

<p align="center">
  <img src="images/sql/02_val_category.png">
  <img src="images/sql/02_nor_category.png">
  <br>
  <em>Figura: Registros de la columna Category antes y después de su normalización.</em>
</p>

#### Sub-Category

Se validaron **17 subcategorías**:

<p align="center">
  <img src="images/sql/03_val_subcat.png">
  <img src="images/sql/03_val_subcat2.png">
  <br>
  <em>Figura: Registros de la columna Subcategory.</em>
</p>

#### Dates

`Order Date` y `Ship Date` tenían diferentes formatos de fecha. Se normalizaron a tipos de fecha consistentes.

<p align="center">
  <img src="images/sql/04_val_dates.png">
  <img src="images/sql/04_nor_dates.png">
  <br>
  <em>Figura: Registros de la columna Order Date antes y después de su normalización.</em>
</p>

#### Discount

Para los descuentos se detectó un valor anómalo ($5.5$) y se normalizó a $0.55$ interpretándolo como 55% y no como 550%.

#### IDs de clientes

Se detectó el caso de `Harry Olson`, asociado a cinco identificadores diferentes. Se estableció un identificador canónico:

```text
HO-15230
```

<p align="center">
  <img src="images/sql/06_harry.png">
  <br>
  <em>Figura: Duplicados en los IDs de clientes.</em>
</p>

#### Geografía

Se detectó una inconsistencia para el código postal `92024`, asociado a dos ciudades. Se estableció como referencia canónica:

```text
United States + 92024 → Encinitas
```

<p align="center">
  <img src="images/sql/07_california.png">
  <br>
  <em>Figura: Incosistencia de un código postal.</em>
</p>

#### Valores faltantes

Los campos vacíos no se trataron todos de la misma manera. Se distinguieron:

```text
Dato observado
Dato recuperable con evidencia
Dato no recuperable
```

Los valores no recuperables permanecieron `NULL`.

---

## Duplicados y control de cardinalidad

El dataset original contenía **10,703 filas** y, después de la eliminación controlada de duplicados, quedaron **10,194 filas**.

Por tanto:

<p align="center">
  <img src="images/sql/05_duplicados.png">
  <br>
  <em>Figura: Duplicados de registros en el dataset.</em>
</p>

La eliminación de duplicados se realizó sobre la combinación completa de atributos relevantes, evitando eliminar registros distintos únicamente porque compartieran un identificador parcial.

Esto es especialmente importante para los productos, porque se detectaron identificadores reutilizados para productos distintos.

---

## Vistas analíticas

Las vistas permiten desacoplar las consultas de análisis de la complejidad del modelo relacional.

Las dos vistas fundamentales utilizadas durante el análisis son:

### `vw_sales_detail`

Proporciona una vista a nivel de **línea de pedido**, adecuada para:

- productos;
- categorías;
- subcategorías;
- descuentos;
- cantidades;
- ventas;
- beneficios.

<p align="center">
  <img src="images/sql/08_view_sales.png">
  <br>
  <em>Figura: Porción de la vista sales_detail.</em>
</p>

### `vw_order_summary`

Proporciona una vista a nivel de **pedido**, adecuada para:

- número de pedidos;
- clientes distintos;
- valor promedio por pedido;
- tiempos de envío;
- modo de envío;
- métricas agregadas de ventas y beneficio.

Esta separación evita un error muy importante: calcular métricas a nivel de pedido sobre una tabla que está multiplicada por sus líneas de detalle.

<p align="center">
  <img src="images/sql/08_view_order.png">
  <br>
  <em>Figura: Porción de la vista order_detail.</em>
</p>

---

## Análisis de negocio desarrollado

La carpeta `sql/analysis/` se dividió en nueve bloques analíticos.

### `01_business_overview.sql`

Establece una visión general del negocio y proporciona los principales KPI:

- ventas;
- beneficio;
- margen;
- pedidos;
- clientes;
- cantidades;
- cobertura y calidad de datos.

Su propósito es establecer una **línea base ejecutiva** antes de entrar en análisis específicos.

### `02_annual_performance.sql`

Analiza la evolución del negocio por año para identificar:

- crecimiento o contracción de ventas;
- evolución del beneficio;
- cambios en margen;
- evolución del volumen de pedidos.

No debe interpretarse el crecimiento de ventas como crecimiento saludable por sí mismo; el beneficio y el margen se consideran en conjunto.

### `03_monthly_trends.sql`

Descompone el comportamiento temporal por mes y permite identificar:

- estacionalidad;
- meses de mayor facturación;
- meses de peor rentabilidad;
- cambios en el comportamiento del negocio dentro de cada año.

### `04_category_analysis.sql`

Compara las categorías principales:

```text
Furniture
Office Supplies
Technology
```

Se analizan ventas, beneficio, volumen y rentabilidad.

### `05_subcategory_analysis.sql`

Profundiza hasta las 17 subcategorías y permite detectar categorías internas con comportamientos muy diferentes.

Esto es importante porque una categoría puede ser rentable en agregado aunque contenga subcategorías con pérdidas.

### `06_product_analysis.sql`

Analiza el desempeño individual de productos.

Se consideran, entre otras métricas:

- ventas;
- beneficio;
- margen comparable;
- volumen de pedidos;
- cantidad;
- descuentos;
- pérdidas.

Para productos se utiliza la clave real del modelo (`product_key`) cuando es necesario, evitando mezclar entidades diferentes que compartan `Product ID`.

### `07_customer_analysis.sql`

Analiza el comportamiento observado de los clientes mediante:

- ventas;
- pedidos;
- beneficio;
- frecuencia;
- ticket promedio;
- margen;
- actividad temporal.

Se diferencia cuidadosamente entre **valor observado durante el periodo** y métricas predictivas como `Customer Lifetime Value`.

### `08_geographic_analysis.sql`

Estudia la distribución del negocio por:

- país;
- región;
- estado/provincia;
- ciudad.

El objetivo es identificar concentración geográfica, mercados relevantes y posibles diferencias regionales en ventas, beneficio y desempeño logístico.

### `09_logistics_analysis.sql`

Analiza:

- `Ship Mode`;
- tiempo de envío;
- pedidos enviados el mismo día;
- pedidos enviados en dos días o menos;
- pedidos con ocho días o más;
- variabilidad del tiempo de envío;
- impacto económico asociado.

Incluye además validaciones de integridad para comprobar que las dimensiones utilizadas durante el análisis no alteran los totales globales.

---

## Procedimientos almacenados

Se construyeron **seis procedimientos almacenados**.

```text
sql/procedures/
├── 01_sp_sales_summary_by_period.sql
├── 02_sp_category_performance_by_period.sql
├── 03_sp_top_products_by_period.sql
├── 04_sp_top_customers_by_period.sql
├── 05_sp_geographic_performance_by_period.sql
└── 06_sp_logistics_performance_by_period.sql
```

### `01_sp_sales_summary_by_period`

Recibe un periodo y devuelve los KPI generales del negocio.

Parámetros:

```text
p_start_date
p_end_date
```

Acepta `NULL` para usar los límites disponibles del dataset.

### `02_sp_category_performance_by_period`

Permite consultar todas las categorías o filtrar una categoría específica dentro de un periodo.

Parámetros:

```text
p_category_name
p_start_date
p_end_date
```

Valida que la categoría exista antes de ejecutar el análisis.

### `03_sp_top_products_by_period`

Devuelve un ranking parametrizable de productos por ventas.

Parámetros:

```text
p_start_date
p_end_date
p_top_n
```

Se incluye validación de límites para evitar solicitudes inválidas o excesivamente grandes.

### `04_sp_top_customers_by_period`

Devuelve un ranking de clientes con indicadores de:

- ventas;
- participación en ventas;
- pedidos;
- actividad temporal;
- beneficio;
- margen;
- ticket promedio;
- pérdidas;
- cobertura de datos.

### `05_sp_geographic_performance_by_period`

Permite analizar ciudades con filtros opcionales por:

```text
Country
Region
Start Date
End Date
```

Los rankings se calculan dentro del conjunto filtrado.

### `06_sp_logistics_performance_by_period`

Permite analizar logística por modalidad de envío y periodo.

El parámetro de modalidad acepta el valor lógico `Unknown` para representar los registros cuyo `ship_mode` original era `NULL`.

Se utiliza un parámetro suficientemente amplio (`VARCHAR(100)`) para que una entrada inválida pueda ser validada por el procedimiento y produzca un mensaje controlado, en lugar de fallar prematuramente por longitud.

---

## Triggers y auditoría

La auditoría se diseñó sobre las dos tablas transaccionales principales:

```text
orders
order_details
```

Se crearon seis triggers:

```text
sql/triggers/
├── 01_trg_orders_after_insert.sql
├── 02_trg_orders_after_update.sql
├── 03_trg_orders_after_delete.sql
├── 04_trg_order_details_after_insert.sql
├── 05_trg_order_details_after_update.sql
└── 06_trg_order_details_after_delete.sql
```

Y un archivo de validación integral:

```text
07_validate_audit_system.sql
```

### Ciclo de auditoría

```text
orders
├── INSERT → registra NEW
├── UPDATE → registra OLD + NEW
└── DELETE → registra OLD

order_details
├── INSERT → registra NEW
├── UPDATE → registra OLD + NEW
└── DELETE → registra OLD
```

---

## Tabla `audit_log`

La infraestructura de auditoría se implementó mediante:

```text
sql/ddl/05_create_audit_table.sql
```

La tabla contiene:

```text
audit_id
table_name
record_key
action_type
changed_at
changed_by
connection_id
old_data
new_data
```

### Decisión de usar JSON

`old_data` y `new_data` son columnas `JSON` para permitir que la misma tabla de auditoría almacene estados de entidades con estructuras diferentes.

El esquema semántico es:

```text
INSERT
old_data = NULL
new_data = estado nuevo

UPDATE
old_data = estado anterior
new_data = estado posterior

DELETE
old_data = estado anterior
new_data = NULL
```

La tabla incluye índices para facilitar búsquedas por:

- tabla + registro;
- tabla + fecha;
- tipo de acción + fecha.

También se definió un `CHECK` para impedir combinaciones inconsistentes entre `action_type`, `old_data` y `new_data`.

---

## Diseño de los triggers `UPDATE`

Los triggers de actualización no registran ruido cuando una sentencia `UPDATE` no modifica realmente ningún valor.

Se comparan `OLD` y `NEW` utilizando el operador null-safe:

```sql
<=>
```

Esto es importante porque permite distinguir correctamente:

```text
NULL → NULL       = sin cambio
NULL → valor      = cambio
valor → NULL      = cambio
valor → mismo     = sin cambio
```

Como resultado, una actualización sin cambios reales no genera un evento innecesario en `audit_log`.

---

## Metadatos de auditoría

Cada evento registra:

```sql
USER()
CONNECTION_ID()
```

`USER()` conserva el usuario y host asociados a la conexión que ejecutó la operación, mientras que `CONNECTION_ID()` permite diferenciar sesiones de MySQL.

Esto proporciona una trazabilidad básica sin necesidad de añadir campos de auditoría directamente a las tablas operativas.

---

## Validación integral de auditoría

El archivo:

```text
sql/triggers/07_validate_audit_system.sql
```

se diseñó para validar por separado:

1. existencia de los seis triggers;
2. estructura de `audit_log`;
3. índices y restricciones;
4. ciclo `INSERT - UPDATE - DELETE` sobre `orders`;
5. ciclo `INSERT - UPDATE - DELETE` sobre `order_details`;
6. ausencia de ruido por `UPDATE` sin cambios;
7. coherencia global de la auditoría.

Todas las pruebas se plantearon dentro de transacciones y terminaron con `ROLLBACK`.

Por ello, los datos de prueba no contaminan permanentemente el dataset.

---

## Orden de ejecución recomendado

El orden lógico de ejecución de la capa SQL es el siguiente.


### Fase A — Estructura

sql/1. ddl - data definition language:

```text
1. Crear base de datos / esquema
2. Ejecutar DDL de tablas
3. Ejecutar claves primarias
4. Ejecutar claves foráneas
5. Ejecutar restricciones de integridad
```

### Fase B — Carga

sql/2. dml - data manipulation language:

```text
6. Cargar datos de origen
7. Ejecutar transformaciones DML
8. Validar cardinalidades y registros
```

### Fase C — Capa analítica

sql/3. dql - data query language:

```text
9. Crear vistas
10. Validar vw_sales_detail
11. Validar vw_order_summary
```

### Fase D — Análisis

sql/04. analysis:

```text
12. 01_business_overview.sql
13. 02_annual_performance.sql
14. 03_monthly_trends.sql
15. 04_category_analysis.sql
16. 05_subcategory_analysis.sql
17. 06_product_analysis.sql
18. 07_customer_analysis.sql
19. 08_geographic_analysis.sql
20. 09_logistics_analysis.sql
```

### Fase E — Procedimientos

sql/5. procedures:

```text
21. 01_sp_sales_summary_by_period.sql
22. 02_sp_category_performance_by_period.sql
23. 03_sp_top_products_by_period.sql
24. 04_sp_top_customers_by_period.sql
25. 05_sp_geographic_performance_by_period.sql
26. 06_sp_logistics_performance_by_period.sql
```

### Fase F — Auditoría

sql/6. triggers:

```text
27. 05_create_audit_table.sql
28. 01_trg_orders_after_insert.sql
29. 02_trg_orders_after_update.sql
30. 03_trg_orders_after_delete.sql
31. 04_trg_order_details_after_insert.sql
32. 05_trg_order_details_after_update.sql
33. 06_trg_order_details_after_delete.sql
34. 07_validate_audit_system.sql
```

### Regla de dependencia

La regla general es:

```text
DDL
 |
DML / carga
 |
DMQ - Views
 |
Analysis
 |
Procedures
 |
Audit infrastructure
 |
Triggers
 |
Validation
```

Las consultas analíticas dependen de las vistas, los procedimientos dependen de las vistas o tablas analíticas y los triggers dependen de las tablas transaccionales y de `audit_log`.

---

## Validación final de datos

Una vez ejecutadas las transformaciones y antes de utilizar las consultas analíticas como resultados definitivos, se deben comprobar al menos:

```text
Número de filas
Duplicados
Claves primarias
Claves foráneas
Valores NULL
Fechas
Rangos de Discount
Rangos de Quantity
Ventas
Beneficio
Coherencia Order Date / Ship Date
```

### Validaciones logísticas destacadas

Se comprobó específicamente que `shipping_days >= 0` y que las fechas fueran coherentes.

También se verificó la conciliación de totales por diferentes dimensiones. Cuando una dimensión se particiona exhaustivamente, las sumas agregadas deben devolver los mismos totales globales para las métricas aditivas.

Esto se aplicó a:

```text
Ship Mode
Shipping Time Group
Region
Country
Year
```

Las diferencias esperadas son:

```text
order_difference       = 0
order_line_difference  = 0
sales_difference       = 0
quantity_difference    = 0
profit_difference      = 0
```

---

## Conclusión

La capa SQL convierte el dataset de SuperStore en una base analítica estructurada y validada.

El resultado final combina tres niveles:

### Nivel 1 — Datos

```text
Carga
Limpieza
Normalización
Validación
Modelo relacional
```

### Nivel 2 — Análisis

```text
Ventas
Temporalidad
Categorías
Productos
Clientes
Geografía
Logística
```

### Nivel 3 — Reutilización y control

```text
Procedimientos almacenados
Triggers
Auditoría
Validación integral
```

La capa SQL queda así preparada para alimentar las siguientes etapas del proyecto, especialmente Excel/Power Query y Python, sin perder la trazabilidad de cómo se obtuvieron los datos y los indicadores.

