import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from conversation_lab.engine import ConversationEngine
from conversation_lab.evaluator import evaluate_transcript
from conversation_lab.prompts import load_prompt
from conversation_lab.scenarios import load_scenarios
from conversation_lab.user_agents import ScriptedUserAgent


class SimulationTests(unittest.TestCase):
    def test_prompt_contains_single_orchestrator_contract(self):
        prompt = load_prompt("orchestrator_v2")

        self.assertIn("chat|clarify|draft|cancel", prompt)
        self.assertNotIn("[EVENT_DRAFT]", prompt)
        self.assertNotIn("[EVENT_READY]", prompt)

    def test_scripted_user_agent_answers_clarification_and_confirms_draft(self):
        scenario = load_scenarios()[0]
        user = ScriptedUserAgent(scenario)

        self.assertEqual(user.next_message(None), scenario.initial_message)
        self.assertTrue(user.next_message({"action": "clarify", "questions": [{"id": "budget"}]}))
        self.assertEqual(user.next_message({"action": "draft"}), "确认发布")

    def test_rule_based_engine_completes_all_core_scenarios(self):
        engine = ConversationEngine.from_prompt_name("orchestrator_v2", backend="rule")
        failures = []

        for scenario in load_scenarios():
            transcript = engine.run_scenario(scenario)
            report = evaluate_transcript(scenario, transcript)
            if not report.passed:
                failures.append((scenario.id, report.failures))

        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
