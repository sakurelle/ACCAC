SET search_path TO sc_accac;

CREATE OR REPLACE PROCEDURE "sp_add_ANT"(
    IN p_ni_MDL_id integer,
    IN p_ni_CITY_id integer,
    IN p_ni_STAT_id integer,
    IN p_cv_note varchar(255)
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "tb_ANT" (
        "ni_MDL_id",
        "ni_CITY_id",
        "ni_STAT_id",
        "cv_note"
    )
    VALUES (
        p_ni_MDL_id,
        p_ni_CITY_id,
        p_ni_STAT_id,
        p_cv_note
    );
END;
$$;
