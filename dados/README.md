# Dados

Os arquivos CSV não estão versionados neste repositório. Eles podem ser obtidos no conjunto público [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), no Kaggle.

Arquivos utilizados:

- `olist_customers_dataset.csv`
- `olist_orders_dataset.csv`
- `olist_order_payments_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_products_dataset.csv`
- `product_category_name_translation.csv`

## Importação no pgAdmin

Depois de executar `sql/01_criacao_staging.sql`, importe cada CSV na tabela correspondente pelo menu **Import/Export Data** do pgAdmin.

Configuração utilizada:

| Campo | Valor |
|---|---|
| Operação | Import |
| Formato | CSV |
| Encoding | UTF8 |
| Header | Ativado |
| Delimitador | `,` |
| Quote | `"` |
| Escape | `"` |

| Arquivo | Tabela de destino |
|---|---|
| `olist_customers_dataset.csv` | `staging.clientes` |
| `olist_orders_dataset.csv` | `staging.pedidos` |
| `olist_order_payments_dataset.csv` | `staging.pagamentos` |
| `olist_order_items_dataset.csv` | `staging.itens_pedido` |
| `olist_products_dataset.csv` | `staging.produtos` |
| `product_category_name_translation.csv` | `staging.traducao_categorias` |

