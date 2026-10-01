const { parseStatementText } = require("./statementParser");

async function extractText(buffer) {
  const pdfjs =
    await import("pdfjs-dist/legacy/build/pdf.mjs");

  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(buffer),
    disableWorker: true
  });

  const pdf = await loadingTask.promise;
  const pages = [];

  for (
    let pageNumber = 1;
    pageNumber <= pdf.numPages;
    pageNumber += 1
  ) {
    const page = await pdf.getPage(pageNumber);
    const content = await page.getTextContent();

    const rows = [];

    for (const item of content.items) {
      const text = String(item.str || "").trim();

      if (!text) continue;

      const x = Number(item.transform?.[4] || 0);
      const y = Number(item.transform?.[5] || 0);

      let row = rows.find(
        (existingRow) =>
          Math.abs(existingRow.y - y) <= 2.5
      );

      if (!row) {
        row = {
          y,
          parts: []
        };

        rows.push(row);
      }

      row.parts.push({
        x,
        text
      });
    }

    rows.sort(
      (a, b) => b.y - a.y
    );

    const pageText = rows
      .map((row) =>
        row.parts
          .sort((a, b) => a.x - b.x)
          .map((part) => part.text)
          .join(" ")
      )
      .join("\n");

    pages.push(pageText);
  }

  return pages.join("\n").trim();
}

async function ocrPdf(buffer, { maxPages = 8 } = {}) {
  const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
  const { createCanvas } = require("@napi-rs/canvas");
  const Tesseract = require("tesseract.js");

  const loadingTask = pdfjs.getDocument({ data: new Uint8Array(buffer), disableWorker: true });
  const pdf = await loadingTask.promise;
  const pageCount = Math.min(pdf.numPages, maxPages);
  const chunks = [];

  for (let pageNumber = 1; pageNumber <= pageCount; pageNumber += 1) {
    const page = await pdf.getPage(pageNumber);
    const viewport = page.getViewport({ scale: 1.65 });
    const canvas = createCanvas(Math.ceil(viewport.width), Math.ceil(viewport.height));
    const context = canvas.getContext("2d");
    await page.render({ canvasContext: context, viewport }).promise;
    const png = await canvas.encode("png");
    const result = await Tesseract.recognize(png, "eng", { logger: () => {} });
    chunks.push(result?.data?.text || "");
  }

  return {
    text: chunks.join("\n"),
    truncated: pdf.numPages > maxPages,
    totalPages: pdf.numPages,
    processedPages: pageCount
  };
}

async function parseBankStatementPdf(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 5) {
    throw new Error("The uploaded PDF is empty.");
  }
  if (buffer.subarray(0, 5).toString("ascii") !== "%PDF-") {
    throw new Error("The uploaded file is not a valid PDF.");
  }

  let text = "";
  let extractionMethod = "text";
  let ocrInfo = null;

  try {
    text = await extractText(buffer);
  } catch (error) {
    console.warn("PDF text extraction failed:", error.message);
  }

  let result = parseStatementText(text);
  const textLooksUsable = text.length >= 120 && result.transactions.length >= 2;

  if (!textLooksUsable) {
    try {
      ocrInfo = await ocrPdf(buffer);
      extractionMethod = "ocr";
      text = ocrInfo.text;
      result = parseStatementText(text);
      if (ocrInfo.truncated) {
        result.warnings.push(`OCR analyzed the first ${ocrInfo.processedPages} of ${ocrInfo.totalPages} pages. Review the extracted rows carefully.`);
      }
    } catch (error) {
      console.warn("PDF OCR fallback failed:", error.message);
      if (!result.transactions.length) {
        result.warnings.push("This statement appears scanned or uses an unsupported layout. OCR could not confidently recover transactions on this server.");
      }
    }
  }

  return {
    ...result,
    extractionMethod,
    reviewRequired: true,
    privacy: "The PDF was processed in memory and is not stored. Only transactions you approve are saved."
  };
}

module.exports = { parseBankStatementPdf };
