SET search_path TO sc_accac;

CREATE INDEX "idx_tb_CITY_ni_CTR_id"
    ON "tb_CITY" ("ni_CTR_id");

CREATE INDEX "idx_tb_ANT_ni_MDL_id"
    ON "tb_ANT" ("ni_MDL_id");

CREATE INDEX "idx_tb_ANT_ni_CITY_id"
    ON "tb_ANT" ("ni_CITY_id");

CREATE INDEX "idx_tb_ANT_ni_STAT_id"
    ON "tb_ANT" ("ni_STAT_id");

CREATE INDEX "idx_tb_CMP_ni_ANT_id"
    ON "tb_CMP" ("ni_ANT_id");

CREATE INDEX "idx_tb_CMP_ni_CITY_id"
    ON "tb_CMP" ("ni_CITY_id");

CREATE INDEX "idx_tb_CMP_ni_CTR_id"
    ON "tb_CMP" ("ni_CTR_id");

CREATE INDEX "idx_tb_CMP_ni_LYT_id"
    ON "tb_CMP" ("ni_LYT_id");

CREATE INDEX "idx_tb_CMP_bl_visible"
    ON "tb_CMP" ("bl_visible");
