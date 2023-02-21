
{% if var('SponsoredProducts_Portfolio') %}

    {% if is_incremental() %}
    {%- set max_loaded_query -%}
    SELECT coalesce(MAX(_daton_batch_runtime) - 2592000000,0) FROM {{ this }}
    {% endset %}

    {%- set max_loaded_results = run_query(max_loaded_query) -%}

    {%- if execute -%}
    {% set max_loaded = max_loaded_results.rows[0].values()[0] %}
    {% else %}
    {% set max_loaded = 0 %}
    {%- endif -%}
    {% endif %}

    {% set table_name_query %}
    {{set_table_name('%sponsoredproducts%portfolio')}}    
    {% endset %}  

    {% set results = run_query(table_name_query) %}
    {% if execute %}
        {# Return the first column #}
        {% set results_list = results.columns[0].values() %}
        {% set tables_lowercase_list = results.columns[1].values() %}
    {% else %}
        {% set results_list = [] %}
        {% set tables_lowercase_list = [] %}
    {% endif %}

    with final as (
    with unnested_BUDGET as (
    {% for i in results_list %}
        {% if var('get_brandname_from_tablename_flag') %}
            {% set brand =i.split('.')[2].split('_')[var('brandname_position_in_tablename')] %}
        {% else %}
            {% set brand = var('default_brandname') %}
        {% endif %}

        {% if var('get_storename_from_tablename_flag') %}
            {% set store =i.split('.')[2].split('_')[var('storename_position_in_tablename')] %}
        {% else %}
            {% set store = var('default_storename') %}
        {% endif %}

        SELECT *
            From (
            select 
            '{{brand}}' as brand,
            '{{store}}' as store,
            cast(RequestTime as timestamp) RequestTime,
            profileId,
            countryName,
            accountName,
            accountId,
            CAST(fetchDate as Date) fetchDate,
            portfolioId,
            name,
            {% if target.type=='snowflake' %}
            BUDGET.VALUE:amount :: FLOAT as amount,
            BUDGET.VALUE:currencyCode :: VARCHAR as currencyCode,
            BUDGET.VALUE:policy :: VARCHAR as policy,
            BUDGET.VALUE:startDate :: DATE as BudgetStartDate,
            BUDGET.VALUE:endDate :: DATE as BudgetEndDate,
            {% else %}
            BUDGET.amount,
            BUDGET.currencyCode,
            BUDGET.policy,
            BUDGET.startDate,
            BUDGET.endDate,
            {% endif %}
            inBudget,
            state,
	        {{daton_user_id()}} as _daton_user_id,
            {{daton_batch_runtime()}} as _daton_batch_runtime,
            {{daton_batch_id()}} as _daton_batch_id,            
            current_timestamp() as _last_updated,
            '{{env_var("DBT_CLOUD_RUN_ID", "manual")}}' as _run_id
            FROM  {{i}}  
             {{unnesting("BUDGET")}} 
            {% if is_incremental() %}
            {# /* -- this filter will only be applied on an incremental run */ #}
            WHERE {{daton_batch_runtime()}}  >= {{max_loaded}}
            {% endif %}
            {% if not loop.last %} union all {% endif %}
     {% endfor %}

    ))

    select *,
    DENSE_RANK() OVER (PARTITION BY fetchDate, profileId, portfolioId order by _daton_batch_runtime desc) row_num
    FROM unnested_BUDGET
    )

    select * {{exclude()}} (row_num)
    from final
    where row_num = 1

{% endif %}