<div align="center">

# SuperStore Analytics

Proyecto integral de análisis de datos con el conjunto Superstore. Incluye limpieza de datos, diseño de bases de datos relacionales, automatización con SQL (procedimientos, triggers y auditoría) y análisis con Python.

![MySQL](https://img.shields.io/badge/MySQL-8.0%2B-blue?style=for-the-badge)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Stable-success?style=for-the-badge)

</div>

<p align="center">

La proyecto se divide en dos capas principales:

```text
                    SuperStore Analytics
                           │
             ┌─────────────┴─────────────┐
             │                           │
            SQL                         Python
             │                           │
   Ingeniería y análisis        EDA, estadística y
   de datos                     visualización
             │                           │
             └─────────────┬─────────────┘
                           │
                    Business Insights
```


---

## 1. Objetivo

---

## 1. Objetivo

El proyecto busca transformar un dataset transaccional en una solución analítica reproducible capaz de responder preguntas como:

- ¿Cuánto vende el negocio y cuánto beneficio genera?
- ¿Cómo evolucionan ventas, beneficio y margen?
- ¿Qué categorías, subcategorías y productos tienen mejor desempeño?
- ¿Qué clientes generan mayor valor observado?
- ¿Dónde se concentra geográficamente el negocio?
- ¿Cómo se comporta la logística?
- ¿Qué relación existe entre descuentos y rentabilidad?
- ¿Qué tan concentradas están las ventas?
- ¿Qué patrones, outliers y segmentos pueden detectarse con Python?

El proyecto combina ingeniería de datos, modelado relacional, SQL analítico, auditoría, análisis exploratorio y visualización.

---

## 2. Dataset

Fuente:

```text
data/raw/sales_superstore_raw.csv
```

El dataset original contiene **10,703 filas y 21 columnas** relacionadas con pedidos, clientes, productos, geografía, ventas, cantidades, descuentos, beneficios y logística.

Las variables principales son:

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

Los registros están dentro del periodo:

```text
2023-01-03 → 2026-12-30
```

---
