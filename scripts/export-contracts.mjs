import { writeFile } from 'node:fs/promises';
import { z } from 'zod';
import { verdictSchema } from '../backend/functions/lib/evidence.js';
import { contractSchemas } from '../backend/functions/lib/contracts.js';
const definitions = Object.fromEntries(Object.entries(contractSchemas).map(([name,schema]) => {
 const { $schema, ...definition } = z.toJSONSchema(schema);
 return [name,definition];
}));
const contract = {
 $schema:'https://json-schema.org/draft/2020-12/schema',
 $id:'urn:himorning:verification:v1',
 title:'HiMorning verification callable payloads',
 $defs:definitions,
};
await writeFile(new URL('../shared/contracts/v1/verification.schema.json',import.meta.url),JSON.stringify(contract,null,2)+'\n');
console.log('Exported shared/contracts/v1/verification.schema.json');

const { $schema: verdictDialect, ...verdict } = z.toJSONSchema(verdictSchema);
await writeFile(new URL('../backend/inference/verdict.schema.json',import.meta.url),JSON.stringify(verdict,null,2)+'\n');
