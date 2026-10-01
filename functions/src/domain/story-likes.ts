export function nextStoryLikeState(currentCount: unknown, currentlyLiked: boolean): {
  liked: boolean;
  likeCount: number;
} {
  const numericCount = Number(currentCount);
  const safeCount = Number.isSafeInteger(numericCount) && numericCount >= 0
    ? numericCount
    : 0;
  return currentlyLiked
    ? {liked: false, likeCount: Math.max(0, safeCount - 1)}
    : {liked: true, likeCount: safeCount + 1};
}
