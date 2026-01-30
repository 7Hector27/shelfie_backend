import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

export const s3 = new S3Client({
  region: process.env.AWS_REGION,
});

export async function uploadProfileImage(
  buffer: Buffer,
  userId: string,
  contentType: string,
) {
  const ext = contentType.split("/")[1]; // jpeg | png | webp
  const key = `users/${userId}/profile-${Date.now()}.${ext}`;

  await s3.send(
    new PutObjectCommand({
      Bucket: "profile-images-shelfie",
      Key: key,
      Body: buffer,
      ContentType: contentType,
      CacheControl: "public, max-age=31536000",
    }),
  );

  return `https://profile-images-shelfie.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;
}
