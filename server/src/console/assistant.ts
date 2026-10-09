import { createHash } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Store } from "../store.js";
import {
  assistantPolicySchema,
  readAssistantPolicy,
} from "../assistant_policy.js";
import {
  assistantHardPrompt,
  transactionPrompt,
} from "../assistant_boundary.js";
import { requireCondition as check } from "../contract.js";
import { authorize, auditAction } from "./auth.js";

export function registerAssistantManagement(
  app: FastifyInstance,
  store: Store,
) {
  const snapshot = () => {
    const policy = readAssistantPolicy(store);
    return {
      policy,
      revision: createHash("sha256")
        .update(JSON.stringify(policy))
        .digest("hex"),
      assistantHardPrompt,
      transactionPrompt,
    };
  };
  app.get("/ai/assistant-policy", async (request) => {
    authorize(store, request, "ai:policy:view");
    return snapshot();
  });
  app.put("/ai/assistant-policy", async (request) => {
    const admin = authorize(store, request, "ai:policy:edit");
    const input = z
      .strictObject({
        revision: z.string().regex(/^[a-f0-9]{64}$/),
        policy: assistantPolicySchema,
      })
      .parse(request.body);
    return store.db.transaction(() => {
      check(
        snapshot().revision === input.revision,
        "策略已被其他管理员修改，请刷新后重试",
        409,
      );
      store.db
        .prepare("UPDATE assistant_policy SET data_json=? WHERE id=1")
        .run(JSON.stringify(input.policy));
      auditAction(store, admin, "ai:policy:update", "assistant");
      return snapshot();
    })();
  });
}
