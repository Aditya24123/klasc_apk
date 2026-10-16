import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, collectionGroup, updateDoc, deleteDoc, serverTimestamp, runTransaction, writeBatch } from 'firebase/firestore';

let environment;
before(async () => {
  environment = await initializeTestEnvironment({ projectId: 'demo-klasc', firestore: {
    host: '127.0.0.1', port: 8080, rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => environment?.cleanup());
beforeEach(async () => environment.clearFirestore());
const account = uid => environment.authenticatedContext(uid).firestore();
const item = (db, uid, id = '1') => doc(db, `users/${uid}/items/${id}`);
const payload = (ownerId, extra = {}) => ({ id: 1, ownerId, type: 'note', title: 'Private note', content: 'Only this account',
  tags: ['private'], archived: false, imageData: null, created: serverTimestamp(), updated: serverTimestamp(), ...extra });

const shareToken = 'a1'.repeat(32);
async function publish(db, uid, token = shareToken, extra = {}) {
  const source = (await getDoc(item(db, uid))).data();
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}/shares/1`), {token});
  batch.set(doc(db, `shareOwners/${token}`), {ownerId:uid, itemId:'1', sourceCreated:source.created});
  batch.set(doc(db, `publicShares/${token}`), {type:source.type, title:source.title, content:source.content,
    imageData:source.imageData, sharedAt:serverTimestamp(), ...extra});
  return batch.commit();
}
test('public token exposes one sanitized snapshot; visitors cannot list or write', async () => {
  const db = account('A');
  await setDoc(item(db,'A'), payload('A'));
  await setDoc(item(db,'A','2'), payload('A',{id:2,title:'Unshared secret'}));
  await assertSucceeds(publish(db,'A'));
  const visitor = environment.unauthenticatedContext().firestore();
  const ref = doc(visitor,`publicShares/${shareToken}`);
  const row = (await assertSucceeds(getDoc(ref))).data();
  if (Object.keys(row).sort().join(',') !== 'content,imageData,sharedAt,title,type') throw new Error('Public metadata leaked');
  await assertFails(getDocs(collection(visitor,'publicShares')));
  await assertFails(getDocs(collectionGroup(visitor,'publicShares')));
  await assertFails(getDoc(doc(visitor,`shareOwners/${shareToken}`)));
  await assertFails(getDoc(doc(visitor,'users/A/shares/1')));
  await assertFails(getDoc(item(visitor,'A','2')));
  await assertFails(updateDoc(ref,{title:'Visitor edit'}));
  await assertFails(deleteDoc(ref));
  await assertFails(deleteDoc(doc(account('B'),`publicShares/${shareToken}`)));
  await assertFails(getDoc(doc(visitor,'publicShares/1')));
});
test('public schema rejects private metadata, wrong snapshots and forged ownership', async () => {
  const db = account('A');
  await setDoc(item(db,'A'),payload('A'));
  await assertFails(publish(db,'A',shareToken,{ownerId:'A',id:1}));
  await assertFails(publish(db,'A',shareToken,{content:'Forged source'}));
  await assertFails(setDoc(doc(account('B'),`shareOwners/${shareToken}`),{ownerId:'A',itemId:'1',sourceCreated:new Date()}));
  await assertSucceeds(publish(db,'A'));
  await assertFails(updateDoc(doc(db,`shareOwners/${shareToken}`),{itemId:'2'}));
  await assertFails(updateDoc(doc(db,`publicShares/${shareToken}`),{title:'Overwrite snapshot'}));
});
test('revocation denies old token; a new link never reactivates the old one', async () => {
  const db=account('A'); await setDoc(item(db,'A'),payload('A')); await publish(db,'A');
  const visitor=environment.unauthenticatedContext().firestore();
  const batch=writeBatch(db);
  batch.delete(doc(db,`publicShares/${shareToken}`)); batch.delete(doc(db,`shareOwners/${shareToken}`)); batch.delete(doc(db,'users/A/shares/1'));
  await assertSucceeds(batch.commit());
  await assertFails(getDoc(doc(visitor,`publicShares/${shareToken}`)));
  const next='b2'.repeat(32); await assertSucceeds(publish(db,'A',next));
  await assertSucceeds(getDoc(doc(visitor,`publicShares/${next}`)));
  await assertFails(getDoc(doc(visitor,`publicShares/${shareToken}`)));
});
test('deletion disables public access even from older clients; reused ID cannot revive it', async () => {
  const db=account('A'); await setDoc(item(db,'A'),payload('A')); await publish(db,'A');
  const visitor=environment.unauthenticatedContext().firestore();
  await deleteDoc(item(db,'A'));
  await assertFails(getDoc(doc(visitor,`publicShares/${shareToken}`)));
  await setDoc(item(db,'A'),payload('A'));
  await assertFails(getDoc(doc(visitor,`publicShares/${shareToken}`)));
});

test('A can create/read/edit/archive/restore/delete its own item', async () => {
  const db = account('A'), ref = item(db, 'A');
  await assertSucceeds(setDoc(ref, payload('A')));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDocs(collection(db, 'users/A/items')));
  await assertSucceeds(updateDoc(ref, { title: 'Edited', updated: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref, { archived: true, updated: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref, { archived: false, updated: serverTimestamp() }));
  await assertSucceeds(deleteDoc(ref));
});
test('B cannot directly read, list, edit, archive, delete or overwrite A item', async () => {
  await setDoc(item(account('A'), 'A'), payload('A'));
  const db = account('B'), ref = item(db, 'A');
  await assertFails(getDoc(ref));
  await assertFails(getDocs(collection(db, 'users/A/items')));
  await assertFails(updateDoc(ref, { title: 'Hijacked', updated: serverTimestamp() }));
  await assertFails(updateDoc(ref, { archived: true, updated: serverTimestamp() }));
  await assertFails(deleteDoc(ref));
  await assertFails(setDoc(ref, payload('B')));
});
test('anonymous requests cannot read or write private items', async () => {
  await setDoc(item(account('A'), 'A'), payload('A'));
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(item(db, 'A')));
  await assertFails(setDoc(item(db, 'A', '2'), payload('A', {id: 2})));
  await assertFails(deleteDoc(item(db, 'A')));
});
test('owners cannot forge identity, move IDs or rewrite creation time', async () => {
  const db = account('A'), ref = item(db, 'A');
  await assertFails(setDoc(ref, payload('B')));
  await assertFails(setDoc(item(db, 'A', '99'), payload('A')));
  await setDoc(ref, payload('A'));
  await assertFails(updateDoc(ref, { ownerId: 'B', updated: serverTimestamp() }));
  await assertFails(updateDoc(ref, { id: 2, updated: serverTimestamp() }));
  await assertFails(updateDoc(ref, { created: new Date(0), updated: serverTimestamp() }));
});
test('collection-group and unknown-path requests do not bypass ownership', async () => {
  await setDoc(item(account('A'), 'A'), payload('A'));
  const db = account('B');
  await assertFails(getDocs(collectionGroup(db, 'items')));
  await assertFails(getDoc(doc(db, 'items/1')));
  await assertFails(setDoc(doc(db, 'public/1'), payload('B')));
});
test('image documents are private and oversized images are rejected', async () => {
  const db = account('A'), ref = item(db, 'A');
  await assertSucceeds(setDoc(ref, payload('A', {type:'image', content:'', imageData:'aGVsbG8='})));
  await assertFails(getDoc(item(account('B'), 'A')));
  await assertFails(updateDoc(ref, {imageData:'a'.repeat(699053), updated:serverTimestamp()}));
});
test('counter is private, sequential and commits atomically with a created item', async () => {
  const db = account('A'), sequence = doc(db, 'users/A/meta/sequence');
  await assertSucceeds(runTransaction(db, async transaction => {
    await transaction.get(sequence);
    transaction.set(sequence, {nextId:2});
    transaction.set(item(db,'A'), payload('A'));
  }));
  await assertSucceeds(updateDoc(sequence, {nextId:3}));
  await assertFails(updateDoc(sequence, {nextId:1}));
  await assertFails(getDoc(doc(account('B'), 'users/A/meta/sequence')));
  await assertFails(updateDoc(doc(account('B'), 'users/A/meta/sequence'), {nextId:4}));
});
test('a second signed-in client sees the same owner data', async () => {
  const first = account('A'), second = account('A');
  await setDoc(item(first,'A'), payload('A'));
  const snapshot = await assertSucceeds(getDoc(item(second,'A')));
  if (snapshot.data().content !== 'Only this account') throw new Error('Data was not shared with the second client');
});
