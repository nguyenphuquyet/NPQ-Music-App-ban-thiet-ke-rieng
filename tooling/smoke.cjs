const {chromium}=require('playwright');const fs=require('fs');const assert=require('node:assert/strict');
(async()=>{
const browser=await chromium.launch({channel:'chrome',headless:true});const page=await browser.newPage({viewport:{width:390,height:844}});const errors=[];const calls=[];
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('401'))errors.push(m.text())});page.on('response',r=>{if(r.url().includes('/api/')||r.url().includes('/media/audio'))calls.push([r.status(),r.url()])});
await page.goto('http://localhost:5000',{waitUntil:'domcontentloaded',timeout:60000});await page.waitForTimeout(10000);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click()).catch(()=>{});await page.waitForTimeout(2000);
fs.mkdirSync('tooling/artifacts',{recursive:true});await page.screenshot({path:'tooling/artifacts/mobile.png'});
await page.mouse.click(80,425);await page.waitForTimeout(2000);console.log('DETAIL', (await page.locator('body').innerText()).slice(0,2000));await page.screenshot({path:'tooling/artifacts/detail.png'});
await page.getByText('Phát bài hát',{exact:true}).click({force:true});await page.waitForTimeout(4000);await page.screenshot({path:'tooling/artifacts/mini-player.png'});
await page.mouse.click(110,740);await page.waitForTimeout(800);console.log('PLAYER',(await page.locator('body').innerText()).slice(-1500));await page.screenshot({path:'tooling/artifacts/player.png'});
await page.mouse.click(50,35);await page.waitForTimeout(500);await page.mouse.click(40,25);await page.waitForTimeout(1200);
await page.mouse.click(316,25);await page.waitForTimeout(600);await page.screenshot({path:'tooling/artifacts/dark.png'});
await page.mouse.click(272,25);await page.waitForTimeout(600);await page.locator('input').first().fill('Remix');await page.waitForTimeout(1200);console.log('SEARCH',(await page.locator('body').innerText()).slice(0,1500));await page.screenshot({path:'tooling/artifacts/search.png'});
await page.setViewportSize({width:1180,height:820});await page.waitForTimeout(1000);await page.screenshot({path:'tooling/artifacts/tablet-dark.png'});
console.log('API',JSON.stringify(calls));console.log('ERRORS',JSON.stringify(errors));await browser.close();assert.equal(errors.length,0,'No runtime/layout errors');
})().catch(e=>{console.error(e);process.exitCode=1});

