import fetch from "node-fetch";
import { OpenLibrarySearchResponse } from "../types/openLibrary";

export const searchBooks = async (query: string, limit = 5) => {
  const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(
    query,
  )}&limit=${limit}`;

  const res = await fetch(url, {
    headers: {
      "User-Agent": "Shelfie/1.0",
    },
  });

  if (!res.ok) {
    throw new Error("Open Library search failed");
  }

  const data = (await res.json()) as OpenLibrarySearchResponse;

  return data.docs || [];
};

export const getWorkById = async (id: string) => {
  const res = await fetch(`https://openlibrary.org/works/${id}.json`, {
    headers: { "User-Agent": "Shelfie/1.0" },
  });

  if (!res.ok) {
    throw new Error("Failed to fetch work");
  }

  return res.json();
};

export const getAuthorByKey = async (key: string) => {
  const res = await fetch(`https://openlibrary.org${key}.json`, {
    headers: { "User-Agent": "Shelfie/1.0" },
  });

  if (!res.ok) {
    throw new Error("Failed to fetch author");
  }

  return res.json();
};
