\set ECHO all
\set ON_ERROR_STOP 1

CREATE EXTENSION promscale;

SELECT _prom_catalog.get_or_create_metric_table_name('cpu_usage');
SELECT _prom_catalog.get_or_create_metric_table_name('cpu_total');
CALL _prom_catalog.finalize_metric_creation();
INSERT INTO prom_data.cpu_usage
SELECT timestamptz '2000-01-01 02:03:04'+(interval '1s' * g), 100.1 + g, _prom_catalog.get_or_create_series_id('{"__name__": "cpu_usage", "namespace":"dev", "node": "brain"}')
FROM generate_series(1,10) g;
INSERT INTO prom_data.cpu_usage
SELECT timestamptz '2000-01-01 02:03:04'+(interval '1s' * g), 100.1 + g, _prom_catalog.get_or_create_series_id('{"__name__": "cpu_usage", "namespace":"production", "node": "pinky", "new_tag":"foo"}')
FROM generate_series(1,10) g;
INSERT INTO prom_data.cpu_total
SELECT timestamptz '2000-01-01 02:03:04'+(interval '1s' * g), 100.0, _prom_catalog.get_or_create_series_id('{"__name__": "cpu_total", "namespace":"dev", "node": "brain"}')
FROM generate_series(1,10) g;
INSERT INTO prom_data.cpu_total
SELECT timestamptz '2000-01-01 02:03:04'+(interval '1s' * g), 100.0, _prom_catalog.get_or_create_series_id('{"__name__": "cpu_total", "namespace":"production", "node": "pinky", "new_tag_2":"bar"}')
FROM generate_series(1,10) g;

--this should use a subquery with the Promscale extension but not without
--this is thanks to the support function make_call_subquery_support
ANALYZE;
EXPLAIN (costs off) SELECT time, value, prom_api.jsonb(labels), prom_api.val(namespace_id) FROM prom_metric.cpu_usage WHERE labels OPERATOR(prom_api.?) ('namespace' OPERATOR(ps_tag.!==) 'dev' ) ORDER BY time, series_id LIMIT 5;
