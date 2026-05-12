SET search_path TO sc_accac;

CREATE TRIGGER "trg_check_tb_CMP"
BEFORE INSERT OR UPDATE
ON "tb_CMP"
FOR EACH ROW
EXECUTE FUNCTION "fn_check_tb_CMP"();
