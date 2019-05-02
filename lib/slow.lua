--MIT License
--
--Copyright (c) 2019 @ym2601 (https://github.com/sanwabear)
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

local max = 0
local count = 0
local input_accept_frame = 0
local pause = 0xFF
local unpause = 0x00
local phase = 0 -- 0 = active, 1 = pre-pause, 2 = pause
local no_buttons = {}
local keyids = {
	{ "P1 Button A", "a1" },
	{ "P1 Button B", "b1" },
	{ "P1 Button C", "c1" },
	{ "P1 Button D", "d1" },
	{ "P2 Button A", "a2" },
	{ "P2 Button B", "b2" },
	{ "P2 Button C", "c2" },
	{ "P2 Button D", "d2" },
}
local buttons = {}
local offs = {}
local nexts = {}
local _, _, _, ck, _ = rb2key.capture_keys()
for i = 1, #keyids do
	local id1, id2 = keyids[i][1], keyids[i][2]
	buttons[id1] = 0 < ck[id2]
	nexts[id1] = false
	offs[id1] = true
end

local do_pause = function(v)
	memory.writebyte(0x104191, v)
	memory.writebyte(0x1041D2, v)
end

-- �������ςōU���{�^�����F�������悤�ɂ���
local checkkey = function()
	local _, _, _, ck, _ = rb2key.capture_keys()
	local x = max - 1
	for i = 1, #keyids do
		local id1, id2 = keyids[i][1], keyids[i][2]
		if buttons[id1] then
			--�O��ON�̏ꍇ�͗��������m����
			nexts[id1] = nexts[id1] and 0 < ck[id2]
			-- MEMO:�������Ď��̒�~���ɉ����Ȃ������Ƃ��Ɏ��̓���t���[����ON��
			-- �J�n���邩�ǂ����Y�ނ񂾂��A�������Ȃ����Ƃɂ���
		else
			--�O��OFF�̏ꍇ�͉��������m����
			nexts[id1] = nexts[id1] or 0 < ck[id2]
		end
		offs[id1] = offs[id1] and not(buttons[id1] and nexts[id1])
	end
end

local update_buttons = function()
	for i = 1, #keyids do
		local id1, id2 = keyids[i][1], keyids[i][2]
		buttons[id1] = nexts[id1]
	end
end

local unsetkey = function()
	local x = -max
	local tbl = {}
	for i = 1, #keyids do
		local id1, id2 = keyids[i][1], keyids[i][2]
		tbl[keyids[i][1]] = not offs[id1]
		offs[id1] = true -- init
	end
	joypad.set(tbl)
	checkkey()
end
local setkey = function()
	for i = 1, #keyids do
		local id1, id2 = keyids[i][1], keyids[i][2]
		buttons[id1] = nexts[id1]
	end
	joypad.set(buttons)
end

slow = {}
slow.max = function() return max+1 end
slow.apply_slow = function()
	if max == 0 then
		return
	end

	-- �X���[���ɃZ���N�g�Ŕ�����i���j���[����Ȃǂł���悤�Ɂj
	local _, _, k3, ck, _ = rb2key.capture_keys()
	if 0 < ck.sl then
		do_pause(unpause)
		return
	end

	local ec = emu.framecount()
	local state_past = ec - input_accept_frame

	if max < 0 then
		-- �X�e�b�v���s���[�h
		if (20 < ck.st and phase == 2)
			or (20 < state_past and 0 < ck.st and state_past >= ck.st) then
			phase = 1 -- �X�^�[�gON���ɒ�~�̉����J�n
			input_accept_frame = ec
		elseif 1 == state_past then
			phase = 0 -- ��~�̉�������
		elseif (20 < ck.st and phase == 0) then
			-- �X�e�b�v���s���[�h2=�X�^�[�g�������ςŒʏ푬�x��
			if max == -2 then
				return
			else
				phase = 2
			end
		else
			phase = 2
		end
	else
		count = (count + 1) % max
		if count == 0 then
			phase = 0
		elseif count == max-1 then
			phase = 1
		else
			phase = 2
		end
	end

	if phase == 0 then
		update_buttons()
		setkey()
		count = 0
		do_pause(unpause)
	elseif phase == 1 then
		unsetkey()
		do_pause(pause)
	else -- phase == 2
		checkkey()
		do_pause(pause)
	end
end
-- new_max
--  == 0 : slow mode off
--  <= 1 : slow mode
--  >= -1: step mode. start button to next frame
slow.config_slow = function(new_max)
	count = 0
	max = new_max
	input_accept_frame = 0
	local _, _, _, ck, _ = rb2key.capture_keys()
	for i = 1, #keyids do
		local id1, id2 = keyids[i][1], keyids[i][2]
		buttons[id1] = 0 < ck[id2]
		nexts[id1] = false
		offs[id1] = true
	end
end

slow.phase = function()
	if max == 0 then
		return 0
	end
	return phase
end

slow.buttons = function()
	if max == 0 then
		return no_buttons
	end
	return buttons
end

slow.term = function()
	do_pause(unpause)
end
