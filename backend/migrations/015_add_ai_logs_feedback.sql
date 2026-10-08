-- 015_add_ai_logs_feedback.sql
-- Future dataset pipeline (Ch. 26-27): lets a user mark a chat answer
-- as helpful/not-helpful/incorrect, and optionally supply what the
-- correct answer should have been. Nothing here is collected
-- automatically or silently  -  both columns stay NULL unless the user
-- explicitly submits feedback via POST /ai/logs/:id/feedback.
--
-- Deliberately added to the EXISTING ai_logs table rather than a new
-- one: every row already has company_id/user_id/type/input_ref/result,
-- which is exactly the context (Ch. 27's "language", "context") a
-- future MODIRI-specific fine-tuning dataset would need alongside the
-- feedback itself  -  no duplicate storage, no second table to keep in
-- sync (Ch. 30: avoid unnecessary abstractions/duplicate code).
--
-- Privacy (Ch. 27): ai_logs.input_ref is already capped to short
-- excerpts (~500 chars) by ai.service.js, and this module never writes
-- passwords, tokens, or payment details into it. When a MODIRI dataset
-- is eventually assembled from this table, exporting should still go
-- through an explicit, reviewed process  -  this migration only adds
-- the storage, not an automatic export.

CREATE TYPE ai_feedback_enum AS ENUM ('helpful', 'not_helpful', 'incorrect');

ALTER TABLE ai_logs
  ADD COLUMN user_feedback ai_feedback_enum,
  ADD COLUMN corrected_answer TEXT;
