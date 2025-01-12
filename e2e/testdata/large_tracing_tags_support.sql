\set ECHO all
\set ON_ERROR_STOP 1

CREATE EXTENSION promscale;

-- We don't want retention to mess with the test data
SELECT ps_trace.set_trace_retention_period('100 years'::INTERVAL);

CREATE FUNCTION assert(assertion BOOLEAN, msg TEXT)
    RETURNS BOOLEAN
    LANGUAGE plpgsql VOLATILE AS
$fnc$
BEGIN
    ASSERT assertion, msg;
    RETURN assertion;
END;
$fnc$;

/** 
 * Tag table
 **/

SELECT put_tag('service.namespace', gen.kilobytes_of_garbage::jsonb, resource_tag_type())
	FROM (
    SELECT string_agg(n::text, '') AS kilobytes_of_garbage
     FROM generate_series(1, 15272) AS gs (n)
	) AS gen;

SELECT 
  assert(pg_column_size(value) > 2704,
   'tag value is indeed larger than btree''s version 4 maximum row size for an index'
  )
  FROM _ps_trace.tag t WHERE t.key = 'service.namespace';

SELECT 
  assert(pg_column_size(value) > 8160,
   'tag value is indeed larger than maximum non-toasted row size'
  )
  FROM _ps_trace.tag t WHERE t.key = 'service.namespace';

SELECT put_tag('service.namespace', '"testvalue"', resource_tag_type()) AS t1;
\gset
SELECT put_tag('faas.name', '"testvalue"', resource_tag_type()) AS t2;
\gset
SELECT assert(:t1 != :t2, 'tag ids must be distinct when tag keys are');

SELECT put_tag('service.namespace', '{"testvalue": 1}'::jsonb, resource_tag_type()) AS t1;
\gset
SELECT put_tag('service.namespace', '{"testvalue": 2}'::jsonb, resource_tag_type()) AS t2;
\gset
SELECT assert(:t1 != :t2, 'tag ids must be distinct when tag values are');

SELECT put_operation('myservice', 'test', 'unspecified') AS op_tag_id;
\gset
SELECT put_tag('service.name', '"myservice"'::jsonb, resource_tag_type()) AS srvc_tag_id;
\gset

SELECT id AS op_tag_id_stored
  FROM _ps_trace.operation
    WHERE span_kind = 'unspecified'
      AND span_name = 'test'
      AND service_name_id = :srvc_tag_id;
\gset

SELECT assert(:op_tag_id_stored = :op_tag_id, 'operation lookup by tag id must return the same tag');

SELECT put_tag('host.name', '"foobar"'::jsonb, resource_tag_type()) AS host_tag_id;
\gset

SELECT assert(
	get_tag_map(('{"host.name": "foobar", "service.name": "myservice"}')::jsonb)::jsonb
	= 
	jsonb_build_object('1', :srvc_tag_id, '33', :host_tag_id),
	'get tag map must produce the expected result'
);

SELECT _ps_trace.tag_v_eq_matching_tags('service.name', '"myservice"'::jsonb);

SELECT jsonb_object_agg(n::text, n) AS gigantic_tagmap
  FROM generate_series(1, 15272) AS gs (n)
\gset

/** 
 * Span table
 **/

INSERT INTO _ps_trace.span(trace_id,span_id,parent_span_id,operation_id,start_time,end_time,duration_ms,trace_state,span_tags,dropped_tags_count,event_time,dropped_events_count,dropped_link_count,status_code,status_message,instrumentation_lib_id,resource_tags,resource_dropped_tags_count,resource_schema_url_id)
    VALUES
        (E'05a8be0f-bb79-c052-223e-48608580efcf',2625299614982951051,NULL,19,E'2022-04-26 11:44:55.185962+00',E'2022-04-26 11:44:55.288812+00',102.85,NULL,:'gigantic_tagmap',0,E'["2022-04-26 11:44:55.185999+00","2022-04-26 11:44:55.288781+00")',0,0,E'error',E'Exception: FAILED to fetch a lower char',5,:'gigantic_tagmap',0,NULL);

SELECT 
  assert(pg_column_size(r) > 8160,
   'row with tag_map values is indeed larger than maximum non-toasted row size'
  )
  FROM _ps_trace.span r
    WHERE trace_id = E'05a8be0f-bb79-c052-223e-48608580efcf';

/** 
 * Events table
 **/

INSERT INTO _ps_trace.event(time,trace_id,span_id,name,tags)
    VALUES
        (E'2022-04-26 11:44:55.185962+00',E'05a8be0f-bb79-c052-223e-48608580efcf',2625299614982951051,'fooabar',:'gigantic_tagmap');

SELECT 
  assert(pg_column_size(r) > 8160,
   'row with tag_map values is indeed larger than maximum non-toasted row size'
  )
  FROM _ps_trace.event r
    WHERE trace_id = E'05a8be0f-bb79-c052-223e-48608580efcf';

/** 
 * Link table
 **/

INSERT INTO _ps_trace.link(trace_id,span_id,span_start_time,linked_trace_id,linked_span_id,trace_state,tags)
    VALUES
        (E'05a8be0f-bb79-c052-223e-48608580efcf',2625299614982951051,E'2022-04-26 11:44:55.185962+00',E'05a8be0f-bb79-c052-223e-48608580efcf',2625299614982951051,'zzz',:'gigantic_tagmap');

SELECT 
  assert(pg_column_size(r) > 8160,
   'row with tag_map values is indeed larger than maximum non-toasted row size'
  )
  FROM _ps_trace.link r
    WHERE trace_id = E'05a8be0f-bb79-c052-223e-48608580efcf';