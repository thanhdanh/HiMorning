export interface Transaction {
 get<T>(path: string): Promise<T | undefined>;
 set<T extends object>(path: string, value: T): void;
}
export interface Store { transaction<T>(operation: (tx: Transaction) => Promise<T>): Promise<T> }
