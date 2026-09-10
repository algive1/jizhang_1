import { z } from 'zod';
export const identifier = z.string().min(1).max(600);
const text = z.string().max(4000);
const name = z.string().trim().min(1).max(80);
const cents = z.number().int().min(-100000000000000).max(100000000000000);
const flag = z.union([z.literal(0), z.literal(1)]);
const time = z.number().int().min(0);
const common = { id: identifier, book_id: identifier };
const dated = { created_at: time, updated_at: time };
const optionalText = text.nullable().optional();
const nullableId = identifier.nullable().optional();
export const kinds = ['accounts', 'categories', 'transactions', 'goals', 'goal_milestones', 'goal_contributions', 'budgets', 'books'] as const;
export type Kind = typeof kinds[number];
export type Data = Record<string, unknown>;
export const schemas: Record<Kind, z.ZodType<Data>> = {
  accounts: z.strictObject({ ...common, ...dated, name, type: z.enum(['cash','wechat','alipay','debitCard','creditCard','other','liability']), balance_in_cents: cents, opening_balance_in_cents: cents, currency: z.string().regex(/^[A-Z]{3}$/), asset_form: z.enum(['unspecified','cash','walletBalance','demandDeposit','termDeposit','investment','other']), icon: text, color: z.number().int(), sort_order: z.number().int(), is_archived: flag }),
  categories: z.strictObject({ ...common, parent_id: nullableId, name, icon: text, type: z.enum(['expense','income']), sort_order: z.number().int(), is_default: flag, is_archived: flag }),
  transactions: z.strictObject({ ...common, ...dated, user_id: nullableId, type: z.enum(['expense','income','transfer','refund','reimbursement','borrow','lend','repayment','assetPurchase','adjustment']), amount_in_cents: cents, currency: z.string().regex(/^[A-Z]{3}$/), category_id: nullableId, subcategory_id: nullableId, account_id: identifier, destination_account_id: nullableId, merchant: optionalText, note: optionalText, occurred_at: time, deleted_at: time.nullable().optional(), is_recurring: flag, is_one_time: flag, is_large_transaction: flag, is_planned: flag, source: z.enum(['manual','voice','ocr','auto','import']), ai_confidence: z.number().min(0).max(1).nullable().optional(), user_corrected: flag, sync_status: z.string(), device_id: z.null().optional(), original_transaction_id: nullableId, metadata_json: optionalText, duplicate_confidence: z.number().min(0).max(1).nullable().optional(), visibility: z.literal('shared'), created_by: nullableId, updated_by: nullableId, version: z.number().int() }),
  goals: z.strictObject({ ...common, ...dated, name, goal_type: z.enum(['car','travel','homeDownPayment','emergencyFund','wedding','renovation','digitalProduct','education','childrenFamily','healthcare','retirement','debtRepayment','business','caregiving','giftCharity','majorPurchase','custom']), icon: text, target_amount_in_cents: cents.positive(), current_amount_in_cents: cents.nonnegative(), target_date: time, status: z.enum(['active','completed','paused','archived']), description: optionalText, cover_path: z.null().optional(), completion_celebration_shown: flag, created_by: nullableId, updated_by: nullableId, version: z.number().int(), sort_order: z.number().int(), monthly_reservation_in_cents: cents.nonnegative() }),
  goal_milestones: z.strictObject({ id: identifier, goal_id: identifier, amount_in_cents: cents.positive(), title: text, sort_order: z.number().int(), completed_at: time.nullable().optional(), celebration_shown: flag }),
  goal_contributions: z.strictObject({ id: identifier, goal_id: identifier, amount_in_cents: cents, type: z.enum(['deposit','withdraw','adjustment']), source_transaction_id: nullableId, created_at: time, note: optionalText, contributor_user_id: nullableId }),
  budgets: z.strictObject({ ...common, ...dated, month_key: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/), category_id: nullableId, amount_in_cents: cents.positive() }),
  books: z.strictObject({ id: identifier, name: name.max(40), type: z.enum(['family','enterprise']), owner_user_id: identifier, family_id: nullableId, ...dated, is_archived: flag, version: z.number().int() }),
};
export const mutationSchema = z.strictObject({ operationId: identifier, kind: z.enum(kinds), id: identifier, action: z.enum(['upsert','delete']), expectedVersion: z.number().int().nonnegative(), expectedAccountVersion: z.number().int().nonnegative().optional(), expectedGoalVersion: z.number().int().nonnegative().optional(), data: z.record(z.string(), z.unknown()) });
export type Mutation = z.infer<typeof mutationSchema>;
export interface Entity { kind: Kind; id: string; version: number; deleted: boolean; data: Data }
export class ApiError extends Error {
  constructor(public statusCode: number, message: string, public details?: unknown) { super(message); }
}
export function requireCondition(condition: unknown, message: string, status = 400): asserts condition {
  if (!condition) throw new ApiError(status, message);
}
