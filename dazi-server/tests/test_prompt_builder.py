from __future__ import annotations

import unittest

from app.services.prompt_builder import PromptBuilder


class PromptBuilderTests(unittest.TestCase):
    def test_main_conversation_uses_single_orchestrator_prompt(self):
        prompt_names = {item["name"] for item in PromptBuilder.list_prompts()}

        self.assertIn("conversation_orchestrator", prompt_names)
        self.assertNotIn("agent_chat", prompt_names)
        self.assertNotIn("clarification_questions", prompt_names)
        self.assertNotIn("event_extraction", prompt_names)

    def test_conversation_orchestrator_prompt_is_static_without_runtime_state(self):
        prompt = PromptBuilder.build_conversation_orchestrator_prompt()

        self.assertIn("## 输入内容说明", prompt)
        self.assertIn("## 输出组合", prompt)
        self.assertIn("## 固定输出格式", prompt)
        self.assertIn("<reply>", prompt)
        self.assertIn("<question_json>", prompt)
        self.assertNotIn("## 动态上下文", prompt)
        self.assertNotIn("当前会话状态", prompt)
        self.assertNotIn("conversation_state", prompt)
        self.assertNotIn("<draft_reply>", prompt)
        self.assertNotIn("当前位置：上海 徐汇区", prompt)
        self.assertLess(prompt.index("## 输入内容说明"), prompt.index("## 输出组合"))

    def test_conversation_context_message_carries_runtime_profile_and_memory(self):
        context = PromptBuilder.build_conversation_context_message(
            user_name="小明",
            user_city="上海",
            current_location="上海 徐汇区",
            user_interests=["火锅"],
            user_bio="",
            birth_date=None,
            memories=[("constraint", "不吃辣")],
        )

        self.assertIn("## 运行时上下文", context)
        self.assertIn("当前位置：上海 徐汇区", context)
        self.assertIn("不吃辣", context)
        self.assertNotIn("当前会话状态", context)
        self.assertNotIn("[EVENT_DRAFT]", context)
        self.assertNotIn("[EVENT_READY]", context)

    def test_conversation_orchestrator_prompt_uses_lightweight_actions(self):
        prompt = PromptBuilder.build_conversation_orchestrator_prompt()

        self.assertIn("<action>clarify</action>", prompt)
        self.assertIn("<action>draft</action>", prompt)
        self.assertIn("<action>cancel</action>", prompt)
        self.assertNotIn("chat|clarify|draft|cancel", prompt)
        self.assertIn("reply + clarify", prompt)
        self.assertIn("reply + draft", prompt)
        self.assertIn("reply + cancel", prompt)
        self.assertNotIn("id=city", prompt)
        self.assertNotIn("draft.city", prompt)

    def test_conversation_orchestrator_prompt_includes_fixed_age_and_gender_options(self):
        prompt = PromptBuilder.build_conversation_orchestrator_prompt()

        self.assertIn('options 必须且只能是 ["男","女","优先男","优先女","不限"]', prompt)
        self.assertIn('options 必须且只能是 ["+-3","+-5","+-10","不限"]', prompt)
        self.assertIn('default_option_ids 必须是 ["+-5"]', prompt)
        self.assertIn("default_option_ids", prompt)

    def test_conversation_orchestrator_prompt_keeps_input_description_static(self):
        prompt = PromptBuilder.build_conversation_orchestrator_prompt()

        self.assertIn("用户最新输入会作为本轮 user message 提供", prompt)
        self.assertLess(prompt.index("用户最新输入会作为本轮 user message 提供"), prompt.index("## 输出组合"))

    def test_draft_prompt_builder_is_removed(self):
        self.assertFalse(hasattr(PromptBuilder, "build_event_draft_prompt"))

    def test_room_agent_prompt_uses_public_room_context_and_private_boundary(self):
        prompt = PromptBuilder.build_room_agent_reply_prompt(
            agent_name="AI",
            agent_personality="稳重",
            user_name="阿树",
            event_title="周六网球",
            match_summary="双方周六下午上海网球，新手友好，场地费 AA。",
            mentioned_by="阿树",
            user_memories=[("preference", "用户常在虹口活动，周六下午通常有空")],
            participants=["阿树", "小林", "AI(Agent)"],
            public_events_text=(
                "A: 周六网球｜上海｜徐汇｜2026-06-06 15:00-17:00\n"
                "B: 找人打网球｜上海｜徐汇或静安｜时间未确认"
            ),
            agent_dialogue="B: 我这边具体时间还需要用户确认。",
            recent_messages_text="阿树: @AI 能直接定周六下午吗？",
        )

        self.assertIn("双方公开事件、公开协商记录、匹配摘要、聊天室最近消息", prompt)
        self.assertIn("A: 周六网球", prompt)
        self.assertIn("B: 找人打网球", prompt)
        self.assertIn("我这边具体时间还需要用户确认", prompt)
        self.assertIn("用户常在虹口活动", prompt)
        self.assertIn("profile/memory 不能替代本次公开事件字段", prompt)
        self.assertIn("不能直接定，我这边时间还没公开确认，需要你本人先确认", prompt)
        self.assertIn("used_private_context", prompt)


if __name__ == "__main__":
    unittest.main()
