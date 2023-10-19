{% macro timezone_conversion(col_name) %}

    {% if target.type =='snowflake' %}
        cast(CONVERT_TIMEZONE('{{var("to_timezone")}}', {{col_name}}::timestamp_ntz) as {{ dbt.type_timestamp() }})
    {% else %}
        DATETIME_ADD(var1, INTERVAL {{var2}} var3 )
    {% endif %}

{% endmacro %}
