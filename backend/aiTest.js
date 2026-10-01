require("dotenv").config();

async function testAI() {
  const OpenAI = (await import("openai")).default;

  const client = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
  });

  const response = await client.responses.create({
    model: "gpt-5.6-luna",
    input: "Reply with exactly: Ship-a-ton AI connection works!"
  });

  console.log(response.output_text);
}

testAI().catch((error) => {
  console.error(error);
});