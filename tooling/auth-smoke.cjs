const {chromium}=require('playwright');const assert=require('node:assert/strict');
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true});const page=await browser.newPage({viewport:{width:390,height:844}});const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('401'))errors.push(m.text())});
await page.goto('http://localhost:5000');await page.waitForTimeout(10000);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click()).catch(()=>{});await page.waitForTimeout(1000);
await page.mouse.click(356,36);await page.waitForTimeout(800);console.log('FORM',await page.locator('body').innerText());console.log('INPUTS',await page.locator('input').count());
await page.locator('input').nth(0).fill('invalid-test@example.invalid');await page.locator('input').nth(1).fill('wrong-password');
await page.getByText('Đăng nhập',{exact:true}).last().click({force:true});await page.waitForTimeout(2000);await page.screenshot({path:'tooling/artifacts/login.png'});console.log('LOGIN',await page.locator('body').innerText());console.log('ERRORS',JSON.stringify(errors));await browser.close();assert.equal(errors.length,0);
})().catch(e=>{console.error(e);process.exitCode=1});
