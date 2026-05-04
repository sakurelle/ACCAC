SET search_path TO sc_accac;

CREATE OR REPLACE FUNCTION "fn_check_tb_CMP"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW."cv_type" IS NOT NULL
       AND NEW."cv_type" NOT IN (
            'title',
            'rectangle_header',
            'header',
            'rectangle_city',
            'city',
            'rectangle_antenna',
            'antenna_text'
       ) THEN
        RAISE EXCEPTION 'Недопустимое значение cv_type: %', NEW."cv_type";
    END IF;

    IF NEW."ni_x" IS NOT NULL AND NEW."ni_x" < 0 THEN
        RAISE EXCEPTION 'ni_x не может быть меньше 0';
    END IF;

    IF NEW."ni_y" IS NOT NULL AND NEW."ni_y" < 0 THEN
        RAISE EXCEPTION 'ni_y не может быть меньше 0';
    END IF;

    IF NEW."ni_width" IS NOT NULL AND NEW."ni_width" <= 0 THEN
        RAISE EXCEPTION 'ni_width должен быть больше 0';
    END IF;

    IF NEW."ni_height" IS NOT NULL AND NEW."ni_height" <= 0 THEN
        RAISE EXCEPTION 'ni_height должен быть больше 0';
    END IF;

    IF NEW."cv_type" IN ('rectangle_header', 'header')
       AND NEW."ni_CTR_id" IS NULL THEN
        RAISE EXCEPTION 'Для типа % нужно указать ni_CTR_id', NEW."cv_type";
    END IF;

    IF NEW."cv_type" IN ('rectangle_city', 'city')
       AND NEW."ni_CITY_id" IS NULL THEN
        RAISE EXCEPTION 'Для типа % нужно указать ni_CITY_id', NEW."cv_type";
    END IF;

    IF NEW."cv_type" IN ('rectangle_antenna', 'antenna_text')
       AND NEW."ni_ANT_id" IS NULL THEN
        RAISE EXCEPTION 'Для типа % нужно указать ni_ANT_id', NEW."cv_type";
    END IF;

    IF NEW."cv_type" = 'title' AND NEW."cv_text" IS NULL THEN
        RAISE EXCEPTION 'Для title нужно указать cv_text';
    END IF;

    IF NEW."cv_type" = 'header' AND NEW."cv_text" IS NULL THEN
        RAISE EXCEPTION 'Для header нужно указать cv_text';
    END IF;

    IF NEW."cv_type" = 'city' AND NEW."cv_text" IS NULL THEN
        RAISE EXCEPTION 'Для city нужно указать cv_text';
    END IF;

    IF NEW."cv_type" = 'antenna_text' AND NEW."cv_text" IS NULL THEN
        RAISE EXCEPTION 'Для antenna_text нужно указать cv_text';
    END IF;

    RETURN NEW;
END;
$$;
