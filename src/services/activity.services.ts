import { PoolClient } from "pg";

type CreateActivityInput = {
  actorId: string;
  type: string;
  objectType: string;
  objectId: string;
  targetType?: string | null;
  targetId?: string | null;
  metadata?: Record<string, any>;
  externalSource?: string | null;
  externalBookId?: string | null;
};

export async function createActivity(
  client: PoolClient,
  input: CreateActivityInput,
) {
  const {
    actorId,
    type,
    objectType,
    objectId,
    targetType = null,
    targetId = null,
    metadata = {},
    externalSource = null,
    externalBookId = null,
  } = input;

  const { rows } = await client.query(
    `
    INSERT INTO activities (
      actor_id,
      type,
      object_type,
      object_id,
      target_type,
      target_id,
      metadata,
      external_source,
      external_book_id
    )
    VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb,$8,$9)
    RETURNING *
    `,
    [
      actorId,
      type,
      objectType,
      objectId,
      targetType,
      targetId,
      JSON.stringify(metadata),
      externalSource,
      externalBookId,
    ],
  );

  return rows[0];
}
